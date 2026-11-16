// App state and persistence. One JSON blob in shared_preferences, saved with a
// short debounce and flushed when the app goes to the background.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'library.dart';
import 'models.dart';
import 'predict.dart';
import 'templates.dart';

typedef WorkoutStats = ({int done, int planned, double volume});
typedef MetricValue = ({double value, String date, double? delta});
typedef PersonalRecord = ({double kg, String date, String reps});
typedef BodyTrend = ({double? avg7, double? prevAvg7, double? ratePerWeek, int points});
typedef AttemptPlan = ({double projected, String basis, List<double> attempts});
typedef MeetAlignment = ({String? programMeetDate, int deltaDays, bool anyLogged});
typedef Standing = ({double pct, int n, String label});
typedef WeekLoad = ({Map<String, int> sets, Map<String, int> prevSets, List<String> warnings});

class AppStore extends ChangeNotifier {
  static const _key = 'meet_prep_log_v2';
  static const _v1Key = 'meet_prep_log_v1';
  static const defaultStart = '2026-11-10';

  /// A read-only copy of another lifter's data (a coach viewing an athlete).
  /// Nothing is saved, and screens hide their editing controls.
  final bool readOnly;

  /// For a read-only store: the account the data belongs to.
  final String? ownerId;

  AppStore({this.readOnly = false, this.ownerId});

  /// Builds a read-only store from a cloud snapshot.
  factory AppStore.viewer(Map<dynamic, dynamic> json, {String? ownerId}) {
    final s = AppStore(readOnly: true, ownerId: ownerId);
    s._fromJson(json);
    if (s.active == null && s.programs.isNotEmpty) s.activeId = s.programs.last.id;
    s._pickWeek();
    s.loaded = true;
    return s;
  }

  Profile profile = Profile.defaults();
  final List<Program> programs = [];
  String? activeId;
  final Map<String, BodyEntry> body = {}; // ISO date -> entry
  final List<ExerciseDef> customExercises = [];
  final Map<String, CheckIn> checkins = {}; // "<programId>-<week>"
  GymPrefs gym = GymPrefs();
  final List<Meet> meets = [];

  /// App language: 'system', 'en' or 'ar'.
  final localeCode = ValueNotifier<String>('system');

  /// Percentile tables from real competition results (cached separately from backups).
  final List<Percentiles> standing = [];
  String standingSource = '';

  /// True on a fresh install until the lifter finishes the welcome flow.
  bool needsOnboarding = false;

  /// Week shown in the Program tab.
  int week = 1;

  /// Bumped when values change from code (Fill targets, date change, restore...),
  /// so text fields rebuild with the new values.
  int revision = 0;
  bool loaded = false;

  SharedPreferences? _prefs;
  Timer? _saveTimer;

  // ======================================================================
  // persistence
  // ======================================================================

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    var migrated = false;
    var fresh = false;
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map);
      } catch (_) {
        _reset();
      }
    } else {
      final old = _prefs!.getString(_v1Key);
      if (old != null) {
        try {
          _migrateV1(jsonDecode(old) as Map);
          migrated = true;
        } catch (_) {
          _reset();
        }
      } else {
        fresh = true;
      }
    }
    needsOnboarding = fresh;
    _loadStanding();
    if (programs.isEmpty && !fresh) {
      final p = templateById('meet-prep-8').build(defaultStart, 8);
      programs.add(p);
      activeId = p.id;
    }
    if (active == null && programs.isNotEmpty) activeId = programs.last.id;
    _pickWeek();
    loaded = true;
    notifyListeners();
    if (migrated) await flush();
  }

  void _reset() {
    profile = Profile.defaults();
    programs.clear();
    activeId = null;
    body.clear();
    customExercises.clear();
    checkins.clear();
    gym = GymPrefs();
    meets.clear();
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'profile': profile.toJson(),
        'programs': [for (final p in programs) p.toJson()],
        'active': activeId,
        'body': [for (final e in bodySorted) e.toJson()],
        'customExercises': [for (final d in customExercises) d.toJson()],
        'checkins': {for (final e in checkins.entries) e.key: e.value.toJson()},
        'gym': gym.toJson(),
        'meets': [for (final m in meets) m.toJson()],
        'locale': localeCode.value,
      };

  void _fromJson(Map<dynamic, dynamic> j) {
    _reset();
    profile = Profile.fromJson(jm(j['profile']));
    for (final p in jl(j['programs'])) {
      programs.add(Program.fromJson(jm(p)));
    }
    activeId = j['active'] == null ? null : js(j['active']);
    for (final e in jl(j['body'])) {
      final b = BodyEntry.fromJson(jm(e));
      if (b.date.isNotEmpty) body[b.date] = b;
    }
    for (final d in jl(j['customExercises'])) {
      customExercises.add(ExerciseDef.fromJson(jm(d)));
    }
    jm(j['checkins']).forEach((k, v) => checkins['$k'] = CheckIn.fromJson(jm(v)));
    gym = GymPrefs.fromJson(jm(j['gym']));
    for (final m in jl(j['meets'])) {
      meets.add(Meet.fromJson(jm(m)));
    }
    final loc = js(j['locale']);
    localeCode.value = (loc == 'en' || loc == 'ar') ? loc : 'system';
  }

  void setLocale(String code) {
    localeCode.value = code;
    _touch(bump: true);
  }

  /// Version 1 stored settings, logs keyed "w1-tue", bodyweight and check-ins.
  void _migrateV1(Map<dynamic, dynamic> j) {
    _reset();
    final s = jm(j['settings']);
    jm(s['maxes']).forEach((k, v) {
      final n = jd(v);
      if (n != null) profile.maxes['$k'] = n;
    });
    jm(s['goals']).forEach((k, v) {
      final l = [for (final x in jl(v)) jd(x) ?? 0.0];
      if (l.length == 2) profile.goals['$k'] = l;
    });
    final bw = [for (final x in jl(s['bwTarget'])) jd(x) ?? 0.0];
    if (bw.length == 2) profile.bwTarget = bw;
    final start = js(s['start']).isEmpty ? defaultStart : js(s['start']);
    final prog = templateById('meet-prep-8').build(start, 8);
    jm(j['logs']).forEach((k, v) {
      final w = _findIn(prog, '$k');
      if (w == null) return;
      final m = jm(v);
      w.notes = js(m['notes']);
      jm(m['sets']).forEach((exId, rows) {
        for (final slot in w.exercises) {
          if (slot.id == '$exId') {
            slot.log = [for (final r in jl(rows)) LoggedSet.fromJson(jm(r))];
          }
        }
      });
    });
    jm(j['bodyweight']).forEach((d, kg) {
      final v = jd(kg);
      if (v != null) body['$d'] = BodyEntry(date: '$d', weight: v);
    });
    jm(j['checkins']).forEach((wk, v) => checkins['${prog.id}-$wk'] = CheckIn.fromJson(jm(v)));
    programs.add(prog);
    activeId = prog.id;
  }

  void _save() {
    if (readOnly) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }

  Future<void> flush() async {
    if (readOnly) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    await _prefs?.setString(_key, jsonEncode(toJson()));
  }

  void _touch({bool bump = false}) {
    if (bump) revision++;
    _save();
    notifyListeners();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Replaces everything with a backup. Returns false if the text isn't a valid backup.
  bool importJson(String raw) {
    try {
      final j = jsonDecode(raw.trim());
      if (j is! Map || j['programs'] is! List) return false;
      _fromJson(j);
      if (programs.isEmpty) {
        final p = templateById('meet-prep-8').build(defaultStart, 8);
        programs.add(p);
      }
      if (active == null) activeId = programs.last.id;
      needsOnboarding = false;
      _pickWeek();
      _touch(bump: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================================
  // programs and weeks
  // ======================================================================

  Program? get active {
    for (final p in programs) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  int currentWeekOf(Program p) {
    final days = daysBetween(p.start, todayIso());
    if (days < 0) return 1;
    return (days ~/ 7 + 1).clamp(1, p.weeks).toInt();
  }

  void _pickWeek() {
    final p = active;
    week = p == null ? 1 : currentWeekOf(p);
  }

  void selectWeek(int w) {
    week = w;
    revision++;
    notifyListeners();
  }

  (String, String) weekRange(int w) {
    final p = active;
    final a = addDays(p?.start ?? todayIso(), (w - 1) * 7);
    return (a, addDays(a, 6));
  }

  List<Workout> workoutsInWeek(int w) {
    final p = active;
    if (p == null) return [];
    final list = p.workouts.where((x) => x.week == w).toList();
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return list;
  }

  Workout? workout(String id) {
    final p = active;
    return p == null ? null : _findIn(p, id);
  }

  Workout? _findIn(Program p, String id) {
    for (final w in p.workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  void startProgram(ProgramTemplate t, String start, int weeks, String name) {
    final p = t.build(start, weeks);
    if (name.trim().isNotEmpty) p.name = name.trim();
    programs.add(p);
    activeId = p.id;
    _pickWeek();
    _touch(bump: true);
  }

  /// A copy of [src] with the plan only: no logs, readiness, durations or RPE
  /// adjustments, moved to start on [start]. Used when a coach sends a program.
  static Program planOnly(Program src, String start) {
    final shift = src.start.isEmpty ? 0 : daysBetween(src.start, start);
    return Program(
      id: uid('p'),
      templateId: src.templateId,
      name: src.name,
      level: src.level,
      weeks: src.weeks,
      start: start,
      weekLabels: [...src.weekLabels],
      workouts: [
        for (final w in src.workouts) w.copyPlan(id: w.id, week: w.week, date: w.date.isEmpty ? w.date : addDays(w.date, shift)),
      ],
    );
  }

  /// Adds a program a coach sent. Percent targets use this lifter's own maxes.
  void addAssignedProgram(Map<String, dynamic> json, {bool makeActive = true}) {
    final p = Program.fromJson(json);
    final clean = planOnly(p, p.start.isEmpty ? todayIso() : p.start);
    programs.add(clean);
    if (makeActive || active == null) activeId = clean.id;
    _pickWeek();
    _touch(bump: true);
  }

  void switchProgram(String id) {
    activeId = id;
    _pickWeek();
    _touch(bump: true);
  }

  void deleteProgram(String id) {
    programs.removeWhere((p) => p.id == id);
    checkins.removeWhere((k, _) => k.startsWith('$id-'));
    if (activeId == id) activeId = programs.isEmpty ? null : programs.last.id;
    _pickWeek();
    _touch(bump: true);
  }

  void renameProgram(String id, String name) {
    for (final p in programs) {
      if (p.id == id) p.name = name;
    }
    _touch();
  }

  // ---------- workout structure ----------

  /// Workouts in later weeks that share this workout's name (for "apply to later weeks").
  List<Workout> laterSameTitle(Workout w) {
    final p = active;
    if (p == null) return [];
    return p.workouts.where((x) => x.week > w.week && x.title == w.title).toList();
  }

  Workout addWorkout(int week, String title, String date) {
    final w = Workout(id: uid('w'), week: week, title: title, date: date);
    active?.workouts.add(w);
    _touch(bump: true);
    return w;
  }

  void deleteWorkout(String id) {
    active?.workouts.removeWhere((w) => w.id == id);
    _touch(bump: true);
  }

  void renameWorkout(String id, String title) {
    workout(id)?.title = title;
    _touch(bump: true);
  }

  void setWorkoutDate(String id, String date) {
    workout(id)?.date = date;
    _touch(bump: true);
  }

  /// Copies the plan (not the logs) into the next week, 7 days later.
  bool copyWorkoutToNextWeek(String id) {
    final p = active, w = workout(id);
    if (p == null || w == null || w.week >= p.weeks) return false;
    p.workouts.add(w.copyPlan(id: uid('w'), week: w.week + 1, date: addDays(w.date, 7)));
    _touch(bump: true);
    return true;
  }

  int copyWeekToNext(int week) {
    final p = active;
    if (p == null || week >= p.weeks) return 0;
    final src = workoutsInWeek(week);
    for (final w in src) {
      p.workouts.add(w.copyPlan(id: uid('w'), week: week + 1, date: addDays(w.date, 7)));
    }
    _touch(bump: true);
    return src.length;
  }

  // ---------- exercises ----------

  List<ExerciseDef> get library => [...kLibrary, ...customExercises];

  ExerciseDef addCustomExercise(String name, String category, bool barbell, String? pctOf) {
    final d = ExerciseDef(uid('ex'), name, category, barbell: barbell, pctOf: pctOf, custom: true);
    customExercises.add(d);
    _touch();
    return d;
  }

  void deleteCustomExercise(String id) {
    customExercises.removeWhere((d) => d.id == id);
    _touch();
  }

  void addExercise(String workoutId, ExerciseSlot slot, {bool laterWeeks = false}) {
    final w = workout(workoutId);
    if (w == null) return;
    w.exercises.add(slot);
    if (laterWeeks) {
      for (final x in laterSameTitle(w)) {
        if (!x.exercises.any((e) => e.id == slot.id)) x.exercises.add(slot.copyPlan());
      }
    }
    _touch(bump: true);
  }

  void removeExercise(String workoutId, String slotId, {bool laterWeeks = false}) {
    final w = workout(workoutId);
    if (w == null) return;
    w.exercises.removeWhere((e) => e.id == slotId);
    if (laterWeeks) {
      for (final x in laterSameTitle(w)) {
        x.exercises.removeWhere((e) => e.id == slotId);
      }
    }
    _touch(bump: true);
  }

  void moveExercise(String workoutId, String slotId, int delta) {
    final w = workout(workoutId);
    if (w == null) return;
    final i = w.exercises.indexWhere((e) => e.id == slotId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= w.exercises.length) return;
    final s = w.exercises.removeAt(i);
    w.exercises.insert(j, s);
    _touch(bump: true);
  }

  void updateExercise(String workoutId, String slotId,
      {required String name, required String? pctOf, required String cue, required List<PlannedSet> plan}) {
    final s = _slot(workoutId, slotId);
    if (s == null) return;
    s.name = name;
    s.pctOf = pctOf;
    s.cue = cue;
    s.plan = plan;
    _touch(bump: true);
  }

  ExerciseSlot? _slot(String workoutId, String slotId) {
    final w = workout(workoutId);
    if (w == null) return null;
    for (final e in w.exercises) {
      if (e.id == slotId) return e;
    }
    return null;
  }

  // ---------- logging ----------

  LoggedSet _row(ExerciseSlot s, int i) {
    while (s.log.length <= i) {
      s.log.add(LoggedSet());
    }
    return s.log[i];
  }

  void setSetValue(String workoutId, String slotId, int i, String field, String v) {
    final s = _slot(workoutId, slotId);
    if (s == null) return;
    final r = _row(s, i);
    if (field == 'w') r.w = v;
    if (field == 'r') r.r = v;
    if (field == 'rpe') r.rpe = v;
    _touch();
  }

  /// Cycles a set's light: none → good lift → missed → none.
  void cycleSetStatus(String workoutId, String slotId, int i) {
    final s = _slot(workoutId, slotId);
    if (s == null) return;
    final r = _row(s, i);
    r.status = (r.status + 1) % 3;
    _touch();
  }

  void fillTargets(String workoutId, String slotId) {
    final s = _slot(workoutId, slotId);
    if (s == null) return;
    for (var i = 0; i < s.plan.length; i++) {
      final t = s.plan[i];
      final r = _row(s, i);
      final kg = s.targetKg(t, maxesFor(workout(workoutId)!));
      if (r.w.trim().isEmpty && kg != null) r.w = fmt(kg);
      if (r.r.trim().isEmpty && RegExp(r'^\d+$').hasMatch(t.reps)) r.r = t.reps;
    }
    _touch(bump: true);
  }

  void addLogRow(String workoutId, String slotId) {
    final s = _slot(workoutId, slotId);
    if (s == null) return;
    while (s.log.length < s.plan.length) {
      s.log.add(LoggedSet());
    }
    s.log.add(LoggedSet());
    _touch(bump: true);
  }

  void removeLogRow(String workoutId, String slotId) {
    final s = _slot(workoutId, slotId);
    if (s == null || s.log.length <= s.plan.length) return;
    s.log.removeLast();
    _touch(bump: true);
  }

  void setWorkoutNotes(String id, String v) {
    workout(id)?.notes = v;
    _save();
  }

  void setDuration(String id, String v) {
    final w = workout(id);
    if (w == null) return;
    w.durationMin = int.tryParse(v.trim());
    _touch();
  }

  void setWorkoutBodyweight(String id, String v) {
    final w = workout(id);
    if (w == null) return;
    final kg = parseNum(v);
    w.bodyweight = kg;
    if (kg != null && kg >= 30 && kg <= 300) {
      final e = body[w.date];
      if (e == null) {
        body[w.date] = BodyEntry(date: w.date, weight: kg);
      } else {
        e.weight = kg;
      }
    }
    _touch();
  }

  void startWorkout(String id, {Readiness? readiness, double? loadScale}) {
    final w = workout(id);
    if (w == null) return;
    if (readiness != null) w.readiness = readiness;
    if (loadScale != null) w.loadScale = loadScale;
    w.startedAt = DateTime.now().toIso8601String();
    w.completed = false;
    _touch(bump: true);
  }

  void finishWorkout(String id) {
    final w = workout(id);
    if (w == null) return;
    final e = w.elapsedMin;
    if (e != null) w.durationMin = e < 1 ? 1 : e;
    w.completed = true;
    _touch(bump: true);
  }

  void reopenWorkout(String id) {
    final w = workout(id);
    if (w == null) return;
    w.completed = false;
    w.startedAt = null;
    _touch(bump: true);
  }

  // ======================================================================
  // body composition
  // ======================================================================

  List<BodyEntry> get bodySorted => body.values.toList()..sort((a, b) => a.date.compareTo(b.date));

  void upsertBody(BodyEntry e, {String? previousDate}) {
    if (previousDate != null && previousDate != e.date) body.remove(previousDate);
    if (e.isEmpty) {
      body.remove(e.date);
    } else {
      body[e.date] = e;
    }
    _touch(bump: true);
  }

  void deleteBody(String date) {
    body.remove(date);
    _touch(bump: true);
  }

  /// Latest value of a metric and its change since the previous entry that had it.
  MetricValue? latestMetric(double? Function(BodyEntry) f) {
    final list = bodySorted.where((e) => f(e) != null).toList();
    if (list.isEmpty) return null;
    final last = f(list.last)!;
    final prev = list.length > 1 ? f(list[list.length - 2]) : null;
    return (value: last, date: list.last.date, delta: prev == null ? null : last - prev);
  }

  double? get latestWeight => latestMetric((e) => e.weight)?.value;

  ({double avg, int n})? weekAvgWeight(int w) {
    final (a, b) = weekRange(w);
    final v = [
      for (final e in body.values)
        if (e.weight != null && e.date.compareTo(a) >= 0 && e.date.compareTo(b) <= 0) e.weight!
    ];
    if (v.isEmpty) return null;
    return (avg: v.reduce((x, y) => x + y) / v.length, n: v.length);
  }

  // ======================================================================
  // profile and check-ins
  // ======================================================================

  void saveProfile(Profile p) {
    profile = p;
    _touch(bump: true);
  }

  CheckIn checkin(int w) {
    final p = active;
    return checkins.putIfAbsent('${p?.id ?? 'none'}-$w', () => CheckIn());
  }

  void setCheckin(int w, {String? sleep, String? pain, String? notes}) {
    final c = checkin(w);
    if (sleep != null) c.sleep = sleep;
    if (pain != null) c.pain = pain;
    if (notes != null) c.notes = notes;
    _touch();
  }

  // ======================================================================
  // analysis
  // ======================================================================

  // ======================================================================
  // smart coaching: adjusted maxes, RPE auto-regulation, readiness, load
  // ======================================================================

  /// Maxes for one workout: profile maxes, plus RPE adjustments that apply from
  /// its week, times today's load scale from the readiness check.
  Map<String, double> maxesFor(Workout w) {
    final p = active;
    return p == null ? {...profile.maxes} : _maxesIn(p, w);
  }

  Map<String, double> _maxesIn(Program p, Workout w) {
    final out = {...profile.maxes};
    for (final a in p.adjustments) {
      if (w.week >= a.fromWeek && out.containsKey(a.lift)) out[a.lift] = out[a.lift]! + a.kg;
    }
    if (w.loadScale != 1.0) out.updateAll((_, v) => v * w.loadScale);
    return out;
  }

  /// Total RPE adjustment for a lift that applies in a given week.
  double adjustmentFor(String lift, int week) {
    final p = active;
    if (p == null) return 0;
    var kg = 0.0;
    for (final a in p.adjustments) {
      if (a.lift == lift && week >= a.fromWeek) kg += a.kg;
    }
    return kg;
  }

  static double? _rpeHigh(String rpe) {
    final parts = rpe.split(RegExp(r'[–\-]')).map((x) => parseNum(x)).whereType<double>().toList();
    return parts.isEmpty ? null : parts.last;
  }

  /// After a workout: compare the heaviest planned set of each competition lift
  /// with the RPE you logged, and suggest a change for the rest of the program.
  List<Adjustment> suggestAdjustments(Workout w) {
    final p = active;
    if (p == null || w.week >= p.weeks) return [];
    if (p.adjustments.any((a) => a.sourceWorkoutId == w.id)) return [];
    final maxes = _maxesIn(p, w);
    final out = <Adjustment>[];
    for (final s in w.exercises) {
      if (s.lift == null || s.pctOf != s.lift || s.plan.isEmpty) continue;
      if (s.plan.any((t) => t.label.contains('attempt'))) continue;
      // Reference set: the top single if there is one, otherwise the heaviest planned set.
      var ref = s.plan.indexWhere((t) => t.label == 'Top single');
      if (ref < 0) {
        var best = -1.0;
        for (var i = 0; i < s.plan.length; i++) {
          final kg = s.targetKg(s.plan[i], maxes) ?? -1;
          if (kg > best) {
            best = kg;
            ref = i;
          }
        }
      }
      if (ref < 0 || ref >= s.log.length) continue;
      final t = s.plan[ref], x = s.log[ref];
      final target = _rpeHigh(t.rpe);
      final planned = s.targetKg(t, maxes);
      final lifted = parseNum(x.w);
      if (target == null || target < 7 || planned == null || lifted == null) continue;
      final unit = s.lift == 'bench' ? 2.5 : 5.0;
      int steps;
      String why;
      final what = t.label == 'Top single' ? 'Top single' : 'Heaviest set';
      if (x.status == 2) {
        steps = -2;
        why = '$what at ${fmt(lifted)} kg was missed';
      } else {
        final rpe = parseNum(x.rpe);
        if (rpe == null) continue;
        final diff = rpe - target;
        steps = diff <= -1.5 ? 2 : (diff <= -0.75 ? 1 : (diff >= 1.0 ? -1 : 0));
        if (steps > 0 && lifted < planned - 0.1) steps = 0; // used less than planned: no increase
        why = '$what at ${fmt(lifted)} kg felt RPE ${fmt(rpe)} (target ${t.rpe})';
      }
      if (steps == 0) continue;
      out.add(Adjustment(
        id: uid('adj'),
        lift: s.lift!,
        fromWeek: w.week + 1,
        kg: steps * unit,
        reason: why,
        sourceWorkoutId: w.id,
      ));
    }
    return out;
  }

  void applyAdjustments(List<Adjustment> list) {
    final p = active;
    if (p == null || list.isEmpty) return;
    p.adjustments.addAll(list);
    _touch(bump: true);
  }

  void removeAdjustment(String id) {
    active?.adjustments.removeWhere((a) => a.id == id);
    _touch(bump: true);
  }

  /// Sets a new max. RPE adjustments for that lift are cleared, since the new max already includes them.
  void updateMax(String lift, double kg) {
    profile.maxes[lift] = kg;
    active?.adjustments.removeWhere((a) => a.lift == lift);
    _touch(bump: true);
  }

  void setLoadScale(String workoutId, double scale) {
    workout(workoutId)?.loadScale = scale;
    _touch(bump: true);
  }

  void setReadiness(String workoutId, Readiness r) {
    workout(workoutId)?.readiness = r;
    _touch(bump: true);
  }

  String categoryOf(ExerciseSlot s) {
    for (final d in library) {
      if (d.id == s.defId) return d.category;
    }
    return 'Other';
  }

  Map<String, int> _setsByArea(int week) {
    final out = <String, int>{};
    for (final w in workoutsInWeek(week)) {
      for (final e in w.exercises) {
        final cat = categoryOf(e);
        if (cat == 'Conditioning') continue;
        for (final x in e.log) {
          if (x.status == 2 || x.r.trim().isEmpty) continue;
          out[cat] = (out[cat] ?? 0) + 1;
        }
      }
    }
    return out;
  }

  /// Hard sets per area this week and last week, plus fatigue warnings.
  WeekLoad weekLoad(int week) {
    final sets = _setsByArea(week);
    final prev = week > 1 ? _setsByArea(week - 1) : <String, int>{};
    final warnings = <String>[];
    final rpes = <double>[];
    var missed = 0;
    final scores = <int>[];
    for (final w in workoutsInWeek(week)) {
      if (w.readiness != null) scores.add(w.readiness!.score);
      for (final e in w.exercises) {
        if (e.lift == null) continue;
        for (final x in e.log) {
          if (x.status == 2) missed++;
          final r = parseNum(x.rpe);
          if (r != null && x.status != 2) rpes.add(r);
        }
      }
    }
    if (rpes.length >= 3) {
      final avg = rpes.reduce((a, b) => a + b) / rpes.length;
      if (avg >= 8.8) {
        warnings.add('Your competition lifts averaged RPE ${fmt1(avg)} this week. '
            'That is close to max effort; plan an easier week soon.');
      }
    }
    final now = sets.values.fold<int>(0, (a, b) => a + b), before = prev.values.fold<int>(0, (a, b) => a + b);
    if (before >= 10 && now > before * 1.3) {
      warnings.add('You did ${((now / before - 1) * 100).round()}% more hard sets than last week. '
          'Big jumps raise injury risk.');
    }
    if (missed >= 2) warnings.add('$missed missed sets on competition lifts this week.');
    if (scores.length >= 2) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      if (avg < 50) warnings.add('Readiness averaged ${avg.round()} this week. Sleep and food come first.');
    }
    return (sets: sets, prevSets: prev, warnings: warnings);
  }

  /// 7-day average weight, the 7 days before it, and the rate (kg/week) over the last 21 days.
  BodyTrend bodyTrend() {
    final list = bodySorted.where((e) => e.weight != null).toList();
    if (list.isEmpty) return (avg7: null, prevAvg7: null, ratePerWeek: null, points: 0);
    final last = list.last.date;
    double? avg(int fromDaysAgo, int toDaysAgo) {
      final v = [
        for (final e in list)
          if (daysBetween(e.date, last) >= toDaysAgo && daysBetween(e.date, last) <= fromDaysAgo) e.weight!
      ];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    final recent = [for (final e in list) if (daysBetween(e.date, last) <= 21) e];
    double? rate;
    if (recent.length >= 3 && daysBetween(recent.first.date, last) >= 7) {
      final xs = [for (final e in recent) daysBetween(recent.first.date, e.date).toDouble()];
      final ys = [for (final e in recent) e.weight!];
      final mx = xs.reduce((a, b) => a + b) / xs.length, my = ys.reduce((a, b) => a + b) / ys.length;
      var sxy = 0.0, sxx = 0.0;
      for (var i = 0; i < xs.length; i++) {
        sxy += (xs[i] - mx) * (ys[i] - my);
        sxx += (xs[i] - mx) * (xs[i] - mx);
      }
      if (sxx > 0) rate = sxy / sxx * 7;
    }
    return (avg7: avg(6, 0), prevAvg7: avg(13, 7), ratePerWeek: rate, points: recent.length);
  }

  // ======================================================================
  // competition: meets, attempts, alignment, standing
  // ======================================================================

  /// The next meet that hasn't happened yet, or else the most recent one.
  Meet? get currentMeet {
    if (meets.isEmpty) return null;
    final sorted = [...meets]..sort((a, b) => a.date.compareTo(b.date));
    final today = todayIso();
    for (final m in sorted) {
      if (m.date.compareTo(today) >= 0) return m;
    }
    return sorted.last;
  }

  int? daysToMeet(Meet m) => daysBetween(todayIso(), m.date);

  Meet addMeet(String name, String date, String weighIn) {
    final m = Meet(id: uid('meet'), name: name, date: date, weighIn: weighIn);
    meets.add(m);
    _touch(bump: true);
    return m;
  }

  void updateMeet(Meet m, void Function(Meet m) change, {bool bump = false}) {
    change(m);
    _touch(bump: bump);
  }

  void deleteMeet(String id) {
    meets.removeWhere((m) => m.id == id);
    _touch(bump: true);
  }

  /// Projected max for a lift: best e1RM from the last 28 days of logs,
  /// else the entered max plus any RPE adjustments.
  ({double kg, String basis}) projectedMax(String lift) {
    final today = todayIso();
    double? best;
    String? when;
    for (final p in programs) {
      for (final w in p.workouts) {
        if (daysBetween(w.date, today) > 28 || w.date.compareTo(today) > 0) continue;
        for (final e in w.exercises) {
          if (e.lift != lift) continue;
          for (final x in e.log) {
            if (x.status == 2) continue;
            final v = estimatedMax(x.w, x.r, x.rpe);
            if (v != null && (best == null || v > best)) {
              best = v;
              when = '${x.w.trim()} × ${x.r.trim()}${x.rpe.trim().isEmpty ? '' : ' @ RPE ${x.rpe.trim()}'} on ${shortDate(w.date)}';
            }
          }
        }
      }
    }
    final p = active;
    final entered = (profile.maxes[lift] ?? 0) + (p == null ? 0.0 : adjustmentFor(lift, p.weeks));
    if (best != null && best >= entered - 5) return (kg: best, basis: 'Estimated from $when');
    return (kg: entered, basis: 'Your max${p != null && adjustmentFor(lift, p.weeks) != 0 ? ' with RPE adjustments' : ''}');
  }

  /// Suggested attempts: about 91%, 96.5% and 101% of the projected max.
  AttemptPlan suggestAttempts(String lift) {
    final pm = projectedMax(lift);
    final a = [r25(pm.kg * 0.91), r25(pm.kg * 0.965), r25(pm.kg * 1.01)];
    if (a[1] <= a[0]) a[1] = a[0] + 2.5;
    if (a[2] <= a[1]) a[2] = a[1] + 2.5;
    return (projected: pm.kg, basis: pm.basis, attempts: a);
  }

  void fillSuggestedAttempts(Meet m) {
    for (final l in kLifts) {
      final s = suggestAttempts(l).attempts;
      final list = m.attempts[l]!;
      for (var i = 0; i < 3; i++) {
        if (list[i].lights.every((x) => x == 0)) list[i].kg = fmt(s[i]);
      }
    }
    _touch(bump: true);
  }

  /// The program's meet-day workout (last workout with attempts, else the last workout).
  Workout? programMeetDay(Program p) {
    final list = [...p.workouts]..sort((a, b) => a.date.compareTo(b.date));
    if (list.isEmpty) return null;
    for (final w in list.reversed) {
      if (w.exercises.any((e) => e.plan.any((t) => t.label.contains('attempt')))) return w;
    }
    return list.last;
  }

  MeetAlignment alignment(Meet m) {
    final p = active;
    final day = p == null ? null : programMeetDay(p);
    if (p == null || day == null) return (programMeetDate: null, deltaDays: 0, anyLogged: false);
    return (
      programMeetDate: day.date,
      deltaDays: daysBetween(day.date, m.date),
      anyLogged: p.workouts.any((w) => w.hasLog),
    );
  }

  /// Moves the program so its meet day lands on the meet date. Workouts you
  /// already logged keep their dates.
  void alignProgramToMeet(Meet m) {
    final p = active;
    if (p == null) return;
    final a = alignment(m);
    if (a.deltaDays == 0) return;
    if (!a.anyLogged) p.start = addDays(p.start, a.deltaDays);
    for (final w in p.workouts) {
      if (!w.hasLog) w.date = addDays(w.date, a.deltaDays);
    }
    _pickWeek();
    _touch(bump: true);
  }

  void setAttemptKg(Meet m, String lift, int i, String kg) {
    m.attempts[lift]![i].kg = kg;
    _touch();
  }

  void cycleLight(Meet m, String lift, int i, int judge) {
    final l = m.attempts[lift]![i].lights;
    l[judge] = (l[judge] + 1) % 3;
    _touch();
  }

  void setAllLights(Meet m, String lift, int i, int value) {
    m.attempts[lift]![i].lights = [value, value, value];
    _touch();
  }

  void toggleChecklist(Meet m, String item) {
    if (!m.checklist.remove(item)) m.checklist.add(item);
    _touch();
  }

  // ---------- standing from competition data ----------

  static const _standingKey = 'competition_percentiles_v1';

  void _loadStanding() {
    final raw = _prefs?.getString(_standingKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map;
      standing
        ..clear()
        ..addAll([for (final r in jl(j['rows'])) Percentiles.fromJson(jm(r))]);
      standingSource = js(j['source']);
    } catch (_) {
      standing.clear();
    }
  }

  void setStanding(List<Percentiles> rows) {
    if (rows.isEmpty) return;
    standing
      ..clear()
      ..addAll(rows);
    standingSource = rows.first.source;
    _prefs?.setString(_standingKey, jsonEncode({'source': standingSource, 'rows': [for (final r in rows) r.toJson()]}));
    notifyListeners();
  }

  /// Where a value ranks among real lifters of the same sex and division,
  /// in a weight class (or all classes). Null when there is no data yet.
  Standing? standingFor(String metric, double value, {String? weightClass}) {
    final eq = profile.equipped ? 'equipped' : 'classic';
    final cls = weightClass ?? 'all';
    for (final r in standing) {
      if (r.sex == profile.sex && r.equipment == eq && r.weightClass == cls && r.metric == metric && r.cuts.length >= 50) {
        final pct = percentileOf(value, r.cuts);
        final label = cls == 'all'
            ? 'all ${profile.female ? 'women' : 'men'}'
            : (cls.endsWith('+') ? '$cls kg' : '−$cls kg');
        return (pct: pct, n: r.n, label: label);
      }
    }
    return null;
  }

  // ======================================================================
  // onboarding and gym setup
  // ======================================================================

  void completeOnboarding(Profile p, ProgramTemplate t, String start, int weeks, double? bodyweight) {
    profile = p;
    if (bodyweight != null) {
      final d = todayIso();
      body[d] = BodyEntry(date: d, weight: bodyweight);
    }
    needsOnboarding = false;
    startProgram(t, start, weeks, '');
  }

  void updateGym(void Function(GymPrefs g) change) {
    change(gym);
    _touch(bump: true);
  }

  /// Rest after a set: longer for competition lifts and their % variations.
  int restFor(ExerciseSlot s) => (s.lift != null || s.pctOf != null) ? gym.restMain : gym.restAccessory;

  // ======================================================================
  // personal records (across every program)
  // ======================================================================

  /// Heaviest weight lifted for at least 1, 3 and 5 reps, and the best estimated max.
  Map<String, PersonalRecord?> personalRecords(String lift) {
    final out = <String, PersonalRecord?>{'1RM': null, '3RM': null, '5RM': null, 'e1RM': null};
    for (final p in programs) {
      for (final w in p.workouts) {
        for (final e in w.exercises) {
          if (e.lift != lift) continue;
          for (final x in e.log) {
            if (x.status == 2) continue;
            final kg = parseNum(x.w), reps = parseNum(x.r);
            if (kg == null || reps == null || kg <= 0 || reps < 1) continue;
            for (final (key, need) in const [('1RM', 1), ('3RM', 3), ('5RM', 5)]) {
              final cur = out[key];
              if (reps >= need && (cur == null || kg > cur.kg)) {
                out[key] = (kg: kg, date: w.date, reps: x.r.trim());
              }
            }
            final est = estimatedMax(x.w, x.r, x.rpe);
            final cur = out['e1RM'];
            if (est != null && (cur == null || est > cur.kg)) {
              out['e1RM'] = (kg: est, date: w.date, reps: '${x.w.trim()} × ${x.r.trim()}${x.rpe.trim().isEmpty ? '' : ' @ ${x.rpe.trim()}'}');
            }
          }
        }
      }
    }
    return out;
  }

  // ======================================================================
  // CSV export (for spreadsheets and data analysis)
  // ======================================================================

  static String _csv(Object? v) {
    final s = v == null ? '' : '$v';
    return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String exportSetsCsv() {
    final b = StringBuffer(
        'program,level,week,date,workout,exercise,lift,set,label,target_kg,kg,reps,rpe,result,workout_minutes,bodyweight_kg\n');
    for (final p in programs) {
      final list = [...p.workouts]..sort((a, c) => a.date.compareTo(c.date));
      for (final w in list) {
        for (final e in w.exercises) {
          for (var i = 0; i < e.log.length; i++) {
            final x = e.log[i];
            if (x.isEmpty) continue;
            final t = i < e.plan.length ? e.plan[i] : null;
            final target = t == null ? null : e.targetKg(t, _maxesIn(p, w));
            final result = x.status == 1 ? 'good' : (x.status == 2 ? 'missed' : '');
            b.writeln([
              p.name, p.level, w.week, w.date, w.title, e.name, e.lift ?? '', i + 1, t?.label ?? '',
              target == null ? '' : fmt(target), x.w.trim(), x.r.trim(), x.rpe.trim(), result,
              w.durationMin ?? '', w.bodyweight == null ? '' : fmt(w.bodyweight!),
            ].map(_csv).join(','));
          }
        }
      }
    }
    return b.toString();
  }

  String exportBodyCsv() {
    final b = StringBuffer(
        'date,weight_kg,skeletal_muscle_kg,fat_mass_kg,body_fat_pct,lean_mass_kg,body_water_l,visceral_level,bmr_kcal,inbody_score,waist_cm,note\n');
    String n(double? v) => v == null ? '' : fmt(v);
    for (final e in bodySorted) {
      b.writeln([
        e.date, n(e.weight), n(e.smm), n(e.fatMass), n(e.bodyFatPct), n(e.leanMass), n(e.water),
        n(e.visceral), n(e.bmr), n(e.score), n(e.waist), e.note,
      ].map(_csv).join(','));
    }
    return b.toString();
  }

  // ======================================================================
  // analysis
  // ======================================================================

  String statusOf(Workout w) {
    if (w.completed) return 'done';
    if (w.isLive) return 'live';
    if (w.hasLog) return 'logged';
    if (w.date.compareTo(todayIso()) < 0) return 'missed';
    return 'planned';
  }

  int? durationOf(Workout w) => w.isLive ? w.elapsedMin : w.durationMin;

  WorkoutStats stats(Workout w) {
    var done = 0, planned = 0;
    var vol = 0.0;
    for (final e in w.exercises) {
      planned += e.plan.length;
      for (final x in e.log) {
        if (x.status == 2) continue;
        if (x.status == 1 || x.r.trim().isNotEmpty) done++;
        final kg = parseNum(x.w), reps = parseNum(x.r);
        if (kg != null && reps != null && kg > 0 && reps > 0) vol += kg * reps;
      }
    }
    return (done: done, planned: planned, volume: vol);
  }

  /// Best estimated max per week for one competition lift in the active program.
  Map<int, double> bestByWeek(String lift) {
    final out = <int, double>{};
    final p = active;
    if (p == null) return out;
    for (final w in p.workouts) {
      for (final e in w.exercises) {
        if (e.lift != lift) continue;
        for (final x in e.log) {
          if (x.status == 2) continue;
          final v = estimatedMax(x.w, x.r, x.rpe);
          if (v != null && (out[w.week] == null || v > out[w.week]!)) out[w.week] = v;
        }
      }
    }
    return out;
  }

  /// Every estimated max for a lift across all programs (best per day), for prediction.
  List<E1rmPoint> e1rmLog(String lift) {
    final best = <String, double>{};
    for (final p in programs) {
      for (final w in p.workouts) {
        if (!_isIso(w.date)) continue;
        for (final e in w.exercises) {
          if (e.lift != lift) continue;
          for (final x in e.log) {
            if (x.status == 2) continue;
            final v = estimatedMax(x.w, x.r, x.rpe);
            if (v != null && (best[w.date] == null || v > best[w.date]!)) best[w.date] = v;
          }
        }
      }
    }
    return [for (final e in best.entries) (date: e.key, kg: e.value)]..sort((a, b) => a.date.compareTo(b.date));
  }

  static bool _isIso(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);

  /// Where a lift is heading by [target] (an ISO date), or null without enough data.
  Prediction? predict(String lift, String target) => predictLift(lift, e1rmLog(lift), todayIso(), target);

  /// Predictions for all three lifts on [target], or null when any lift lacks data.
  ({Prediction squat, Prediction bench, Prediction deadlift, double total, double low, double high})? predictTotal(
      String target) {
    final s = predict('squat', target), b = predict('bench', target), d = predict('deadlift', target);
    if (s == null || b == null || d == null) return null;
    final total = s.kg + b.kg + d.kg;
    // The three ranges are partly independent, so the total's range is narrower than their sum.
    double half(Prediction p) => (p.high - p.low) / 2;
    final spread = math.sqrt(math.pow(half(s), 2) + math.pow(half(b), 2) + math.pow(half(d), 2));
    return (squat: s, bench: b, deadlift: d, total: total, low: total - spread, high: total + spread);
  }

  double? bestOverall(String lift) {
    final m = bestByWeek(lift);
    if (m.isEmpty) return null;
    return m.values.reduce((a, b) => a > b ? a : b);
  }

  double? gl(double total, double? bw) =>
      bw == null ? null : glPoints(total, bw, female: profile.female, equipped: profile.equipped);

  /// Points with this lifter's formula (their federation's, unless they chose another).
  double? points(double total, double? bw) => bw == null
      ? null
      : scorePoints(profile.scoreFormula, total, bw, female: profile.female, equipped: profile.equipped);

  /// Name of this lifter's formula, e.g. 'GL points' or 'DOTS'.
  String get pointsName => kScoreNames[profile.scoreFormula] ?? 'GL points';

  static String? _fmtRows(List<LoggedSet> rows) {
    final list = rows.where((x) => x.w.trim().isNotEmpty || x.r.trim().isNotEmpty).toList();
    if (list.isEmpty) return null;
    final groups = <({LoggedSet x, int n})>[];
    for (final x in list) {
      final g = groups.isEmpty ? null : groups.last;
      if (g != null && g.x.w == x.w && g.x.r == x.r && g.x.status == x.status) {
        groups[groups.length - 1] = (x: g.x, n: g.n + 1);
      } else {
        groups.add((x: x, n: 1));
      }
    }
    final sets = groups.map((g) {
      final base = '${g.x.w.isNotEmpty ? '${g.x.w} kg × ' : '× '}${g.x.r}${g.n > 1 ? ' × ${g.n}' : ''}';
      return g.x.status == 2 ? '$base (missed)' : base;
    }).join(', ');
    final rpes = list.map((x) => x.rpe.trim()).where((v) => v.isNotEmpty).toList();
    return rpes.isEmpty ? sets : '$sets — RPE ${rpes.join(', ')}';
  }

  String checkinText(int w) {
    final p = active;
    if (p == null) return '';
    final (a, b) = weekRange(w);
    final c = checkin(w);
    final avg = weekAvgWeight(w);
    final lines = <String>[
      'WEEK $w CHECK-IN · ${p.name} (${p.level}) · ${shortDate(a)} – ${shortDate(b)}',
      'Bodyweight (avg of weigh-ins): ${avg == null ? '__ kg' : '${fmt1(avg.avg)} kg (${avg.n} weigh-ins)'}',
    ];
    for (final e in body.values) {
      if (e.date.compareTo(a) < 0 || e.date.compareTo(b) > 0) continue;
      final parts = [
        if (e.bodyFatPct != null) 'body fat ${fmt1(e.bodyFatPct!)}%',
        if (e.smm != null) 'muscle ${fmt1(e.smm!)} kg',
        if (e.visceral != null) 'visceral ${fmt(e.visceral!)}',
        if (e.waist != null) 'waist ${fmt1(e.waist!)} cm',
      ];
      if (parts.isNotEmpty) lines.add('Body scan ${shortDate(e.date)}: ${parts.join(', ')}');
    }
    for (final x in workoutsInWeek(w)) {
      final dur = durationOf(x);
      final meta = [
        shortDate(x.date),
        if (dur != null) fmtDuration(dur),
        if (x.bodyweight != null) 'BW ${fmt(x.bodyweight!)}',
      ].join(', ');
      final state = x.completed ? '' : (x.hasLog ? ' — not finished' : ' — not logged');
      lines.add('${weekdayName(x.date)} · ${x.title} ($meta)$state');
      for (final e in x.exercises) {
        final t = _fmtRows(e.log);
        if (t != null) lines.add('  ${e.name}: $t');
      }
      if (x.notes.trim().isNotEmpty) lines.add('  Notes: ${x.notes.trim()}');
    }
    lines.add('Sleep (avg hours): ${c.sleep.isEmpty ? '__' : c.sleep}');
    lines.add('Pain/tightness anywhere: ${c.pain.isEmpty ? 'none' : c.pain}');
    lines.add('Notes (bar speed, technique, energy): ${c.notes.isEmpty ? '__' : c.notes}');
    return lines.join('\n');
  }
}

/// Makes the store available to every screen.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  /// Use in build methods: rebuilds when the store changes.
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Use in callbacks: no rebuild dependency.
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
