// Data model. Every class round-trips through JSON for local storage and backups.
import 'calc.dart';

// ---------- JSON helpers ----------

double? jd(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String js(dynamic v) => v == null ? '' : '$v';
int? ji(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
List<dynamic> jl(dynamic v) => v is List ? v : const [];
Map<dynamic, dynamic> jm(dynamic v) => v is Map ? v : const {};

int _seq = 0;

/// Short unique id, e.g. "w-lx3k9a1".
String uid([String prefix = 'id']) {
  _seq++;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_seq.toRadixString(36)}';
}

// ---------- sets ----------

/// A planned set. The load is either a percentage of a competition max (pct, e.g. 0.75)
/// or a fixed weight in kg. Reps is text so it can hold "8 / leg" or "45–60 s".
class PlannedSet {
  double? pct;
  double? kg;
  String reps;
  String rpe;
  String label; // "Top single", "1st attempt", ...

  PlannedSet({this.pct, this.kg, this.reps = '', this.rpe = '', this.label = ''});

  PlannedSet copy() => PlannedSet(pct: pct, kg: kg, reps: reps, rpe: rpe, label: label);

  Map<String, dynamic> toJson() => {
        if (pct != null) 'pct': pct,
        if (kg != null) 'kg': kg,
        'reps': reps,
        if (rpe.isNotEmpty) 'rpe': rpe,
        if (label.isNotEmpty) 'label': label,
      };

  factory PlannedSet.fromJson(Map<dynamic, dynamic> j) => PlannedSet(
        pct: jd(j['pct']),
        kg: jd(j['kg']),
        reps: js(j['reps']),
        rpe: js(j['rpe']),
        label: js(j['label']),
      );
}

/// A logged set. status: 0 = not marked, 1 = good lift (white light), 2 = missed (red light).
class LoggedSet {
  String w;
  String r;
  String rpe;
  int status;

  LoggedSet({this.w = '', this.r = '', this.rpe = '', this.status = 0});

  bool get isEmpty => w.trim().isEmpty && r.trim().isEmpty && rpe.trim().isEmpty && status == 0;

  Map<String, dynamic> toJson() => {'w': w, 'r': r, 'rpe': rpe, if (status != 0) 's': status};

  factory LoggedSet.fromJson(Map<dynamic, dynamic> j) =>
      LoggedSet(w: js(j['w']), r: js(j['r']), rpe: js(j['rpe']), status: ji(j['s']) ?? 0);
}

// ---------- exercises ----------

class ExerciseSlot {
  String id; // unique inside its workout; the same id across weeks means "the same slot"
  String defId; // library exercise id
  String name;
  String? lift; // 'squat' | 'bench' | 'deadlift' for the competition lifts (counts toward e1RM)
  String? pctOf; // whose max the percentages use
  bool barbell; // show plate math
  String cue;
  List<PlannedSet> plan;
  List<LoggedSet> log;

  ExerciseSlot({
    required this.id,
    required this.defId,
    required this.name,
    this.lift,
    this.pctOf,
    this.barbell = false,
    this.cue = '',
    List<PlannedSet>? plan,
    List<LoggedSet>? log,
  })  : plan = plan ?? [],
        log = log ?? [];

  double? targetKg(PlannedSet s, Map<String, double> maxes) {
    if (s.pct != null && pctOf != null) {
      final m = maxes[pctOf];
      if (m != null) return r25(m * s.pct!);
    }
    return s.kg;
  }

  bool get hasLog => log.any((x) => !x.isEmpty);

  ExerciseSlot copyPlan() => ExerciseSlot(
        id: id,
        defId: defId,
        name: name,
        lift: lift,
        pctOf: pctOf,
        barbell: barbell,
        cue: cue,
        plan: [for (final s in plan) s.copy()],
      );

  /// "Top single 135 kg @ RPE 8  ·  4 × 3 @ 127.5 kg · RPE 7–8"
  String summary(Map<String, double> maxes) {
    final parts = <String>[];
    var i = 0;
    while (i < plan.length) {
      final t = plan[i];
      final w = targetKg(t, maxes);
      if (t.label.isNotEmpty) {
        parts.add('${t.label}${w == null ? '' : ' ${fmt(w)} kg'}${t.rpe.isNotEmpty ? ' @ RPE ${t.rpe}' : ''}');
        i++;
        continue;
      }
      var n = 1;
      while (i + n < plan.length &&
          plan[i + n].label.isEmpty &&
          targetKg(plan[i + n], maxes) == w &&
          plan[i + n].reps == t.reps &&
          plan[i + n].rpe == t.rpe) {
        n++;
      }
      parts.add('$n × ${t.reps}${w == null ? '' : ' @ ${fmt(w)} kg'}${t.rpe.isNotEmpty ? ' · RPE ${t.rpe}' : ''}');
      i += n;
    }
    return parts.isEmpty ? 'No sets planned' : parts.join('  ·  ');
  }

  Map<String, dynamic> toJson() {
    final rows = [for (final x in log) x.toJson()];
    while (rows.isNotEmpty && LoggedSet.fromJson(rows.last).isEmpty) {
      rows.removeLast();
    }
    return {
      'id': id,
      'def': defId,
      'name': name,
      if (lift != null) 'lift': lift,
      if (pctOf != null) 'pctOf': pctOf,
      if (barbell) 'bar': true,
      if (cue.isNotEmpty) 'cue': cue,
      'plan': [for (final s in plan) s.toJson()],
      if (rows.isNotEmpty) 'log': rows,
    };
  }

  factory ExerciseSlot.fromJson(Map<dynamic, dynamic> j) => ExerciseSlot(
        id: js(j['id']),
        defId: js(j['def']),
        name: js(j['name']),
        lift: j['lift'] == null ? null : js(j['lift']),
        pctOf: j['pctOf'] == null ? null : js(j['pctOf']),
        barbell: j['bar'] == true,
        cue: js(j['cue']),
        plan: [for (final s in jl(j['plan'])) PlannedSet.fromJson(jm(s))],
        log: [for (final s in jl(j['log'])) LoggedSet.fromJson(jm(s))],
      );
}

/// An exercise in the library (built-in or created by the lifter).
class ExerciseDef {
  final String id;
  final String name;
  final String category;
  final bool barbell;
  final String? pctOf;
  final String? lift;
  final bool custom;

  const ExerciseDef(this.id, this.name, this.category,
      {this.barbell = false, this.pctOf, this.lift, this.custom = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        if (barbell) 'bar': true,
        if (pctOf != null) 'pctOf': pctOf,
      };

  factory ExerciseDef.fromJson(Map<dynamic, dynamic> j) => ExerciseDef(
        js(j['id']),
        js(j['name']),
        js(j['category']).isEmpty ? 'Other' : js(j['category']),
        barbell: j['bar'] == true,
        pctOf: j['pctOf'] == null ? null : js(j['pctOf']),
        custom: true,
      );
}

// ---------- workouts and programs ----------

class Workout {
  String id;
  int week;
  String title;
  String timeHint;
  String date; // ISO, editable
  String note; // coach note from the program
  List<ExerciseSlot> exercises;

  // what the lifter logs
  int? durationMin;
  String? startedAt; // ISO date-time while the workout is running
  bool completed;
  double? bodyweight;
  String notes;
  Readiness? readiness;
  double loadScale; // 1.0 = as planned, 0.95 = 5% lighter today

  Workout({
    required this.id,
    required this.week,
    required this.title,
    required this.date,
    this.timeHint = '',
    this.note = '',
    List<ExerciseSlot>? exercises,
    this.durationMin,
    this.startedAt,
    this.completed = false,
    this.bodyweight,
    this.notes = '',
    this.readiness,
    this.loadScale = 1.0,
  }) : exercises = exercises ?? [];

  bool get isLive => startedAt != null && !completed;

  int? get elapsedMin {
    final s = startedAt == null ? null : DateTime.tryParse(startedAt!);
    if (s == null) return null;
    return DateTime.now().difference(s).inMinutes;
  }

  bool get hasLog =>
      completed ||
      startedAt != null ||
      durationMin != null ||
      bodyweight != null ||
      notes.trim().isNotEmpty ||
      exercises.any((e) => e.hasLog);

  Workout copyPlan({required String id, required int week, required String date}) => Workout(
        id: id,
        week: week,
        title: title,
        timeHint: timeHint,
        date: date,
        note: note,
        exercises: [for (final e in exercises) e.copyPlan()],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'week': week,
        'title': title,
        if (timeHint.isNotEmpty) 'time': timeHint,
        'date': date,
        if (note.isNotEmpty) 'note': note,
        'ex': [for (final e in exercises) e.toJson()],
        if (durationMin != null) 'dur': durationMin,
        if (startedAt != null) 'started': startedAt,
        if (completed) 'done': true,
        if (bodyweight != null) 'bw': bodyweight,
        if (notes.isNotEmpty) 'notes': notes,
        if (readiness != null) 'ready': readiness!.toJson(),
        if (loadScale != 1.0) 'scale': loadScale,
      };

  factory Workout.fromJson(Map<dynamic, dynamic> j) => Workout(
        id: js(j['id']),
        week: ji(j['week']) ?? 1,
        title: js(j['title']),
        timeHint: js(j['time']),
        date: js(j['date']),
        note: js(j['note']),
        exercises: [for (final e in jl(j['ex'])) ExerciseSlot.fromJson(jm(e))],
        durationMin: ji(j['dur']),
        startedAt: j['started'] == null ? null : js(j['started']),
        completed: j['done'] == true,
        bodyweight: jd(j['bw']),
        notes: js(j['notes']),
        readiness: j['ready'] is Map ? Readiness.fromJson(jm(j['ready'])) : null,
        loadScale: jd(j['scale']) ?? 1.0,
      );
}

/// How ready the lifter felt before a workout. Energy, soreness and stress are 1–5.
class Readiness {
  double sleepHours;
  int energy; // 1 = drained, 5 = great
  int soreness; // 1 = none, 5 = very sore
  int stress; // 1 = calm, 5 = very stressed

  Readiness({this.sleepHours = 7, this.energy = 3, this.soreness = 2, this.stress = 2});

  /// 0–100. Sleep counts most, then energy, soreness and stress.
  int get score {
    double c(double v) => v.clamp(0.0, 1.0).toDouble();
    final s = c((sleepHours - 4) / 4);
    final e = c((energy - 1) / 4);
    final so = c((5 - soreness) / 4);
    final st = c((5 - stress) / 4);
    return (100 * (0.35 * s + 0.30 * e + 0.20 * so + 0.15 * st)).round();
  }

  /// Suggested load for today's main lifts.
  double get suggestedScale => score < 35 ? 0.90 : (score < 50 ? 0.95 : 1.0);

  String get advice {
    final v = score;
    if (v >= 70) return 'Good to go. Train as planned.';
    if (v >= 50) return 'Moderate. Keep the main lift as planned and drop a back-off set if bar speed slows.';
    if (v >= 35) return 'Low. Take the main lifts about 5% lighter today and keep the technique sharp.';
    return 'Very low. Go about 10% lighter, or make today a technique session.';
  }

  Map<String, dynamic> toJson() =>
      {'sleep': sleepHours, 'energy': energy, 'soreness': soreness, 'stress': stress, 'score': score};

  factory Readiness.fromJson(Map<dynamic, dynamic> j) => Readiness(
        sleepHours: jd(j['sleep']) ?? 7,
        energy: ji(j['energy']) ?? 3,
        soreness: ji(j['soreness']) ?? 2,
        stress: ji(j['stress']) ?? 2,
      );
}

/// A change to a competition max for the rest of a program, from RPE feedback.
class Adjustment {
  String id;
  String lift;
  int fromWeek;
  double kg;
  String reason;
  String sourceWorkoutId;

  Adjustment({
    required this.id,
    required this.lift,
    required this.fromWeek,
    required this.kg,
    required this.reason,
    required this.sourceWorkoutId,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'lift': lift, 'from': fromWeek, 'kg': kg, 'reason': reason, 'src': sourceWorkoutId};

  factory Adjustment.fromJson(Map<dynamic, dynamic> j) => Adjustment(
        id: js(j['id']),
        lift: js(j['lift']),
        fromWeek: ji(j['from']) ?? 1,
        kg: jd(j['kg']) ?? 0,
        reason: js(j['reason']),
        sourceWorkoutId: js(j['src']),
      );
}

class Program {
  String id;
  String templateId;
  String name;
  String level;
  int weeks;
  List<String> weekLabels;
  String start; // ISO date of day 1
  List<Workout> workouts;
  List<Adjustment> adjustments;

  Program({
    required this.id,
    required this.templateId,
    required this.name,
    required this.level,
    required this.weeks,
    required this.start,
    List<String>? weekLabels,
    List<Workout>? workouts,
    List<Adjustment>? adjustments,
  })  : weekLabels = weekLabels ?? [],
        workouts = workouts ?? [],
        adjustments = adjustments ?? [];

  String weekLabel(int w) => (w - 1 < weekLabels.length) ? weekLabels[w - 1] : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'template': templateId,
        'name': name,
        'level': level,
        'weeks': weeks,
        'labels': weekLabels,
        'start': start,
        'workouts': [for (final w in workouts) w.toJson()],
        if (adjustments.isNotEmpty) 'adj': [for (final a in adjustments) a.toJson()],
      };

  factory Program.fromJson(Map<dynamic, dynamic> j) => Program(
        id: js(j['id']),
        templateId: js(j['template']),
        name: js(j['name']),
        level: js(j['level']),
        weeks: ji(j['weeks']) ?? 8,
        start: js(j['start']),
        weekLabels: [for (final s in jl(j['labels'])) js(s)],
        workouts: [for (final w in jl(j['workouts'])) Workout.fromJson(jm(w))],
        adjustments: [for (final a in jl(j['adj'])) Adjustment.fromJson(jm(a))],
      );
}

// ---------- athlete ----------

class Profile {
  String name;
  String sex; // 'male' | 'female'
  double heightCm;
  String division; // 'classic' | 'equipped'
  String weightClass; // e.g. '105', '120+'
  Map<String, double> maxes;
  Map<String, List<double>> goals; // [target, stretch]
  List<double> bwTarget; // meet weight range [low, high]

  Profile({
    required this.name,
    required this.sex,
    required this.heightCm,
    required this.division,
    required this.weightClass,
    required this.maxes,
    required this.goals,
    required this.bwTarget,
  });

  bool get female => sex == 'female';
  bool get equipped => division == 'equipped';
  double? get classLimit => weightClass.endsWith('+') ? null : double.tryParse(weightClass);

  factory Profile.defaults() => Profile(
        name: '',
        sex: 'male',
        heightCm: 185,
        division: 'classic',
        weightClass: '105',
        maxes: {'squat': 150, 'bench': 130, 'deadlift': 200},
        goals: {
          'squat': [165, 170],
          'bench': [132.5, 135],
          'deadlift': [210, 215],
        },
        bwTarget: [100, 103],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex,
        'height': heightCm,
        'division': division,
        'class': weightClass,
        'maxes': maxes,
        'goals': goals,
        'bwTarget': bwTarget,
      };

  factory Profile.fromJson(Map<dynamic, dynamic> j) {
    final d = Profile.defaults();
    final maxes = {...d.maxes};
    jm(j['maxes']).forEach((k, v) {
      final n = jd(v);
      if (n != null) maxes['$k'] = n;
    });
    final goals = {...d.goals};
    jm(j['goals']).forEach((k, v) {
      final l = [for (final x in jl(v)) jd(x) ?? 0.0];
      if (l.length == 2) goals['$k'] = l;
    });
    final bw = [for (final x in jl(j['bwTarget'])) jd(x) ?? 0.0];
    return Profile(
      name: js(j['name']),
      sex: js(j['sex']) == 'female' ? 'female' : 'male',
      heightCm: jd(j['height']) ?? d.heightCm,
      division: js(j['division']) == 'equipped' ? 'equipped' : 'classic',
      weightClass: js(j['class']).isEmpty ? d.weightClass : js(j['class']),
      maxes: maxes,
      goals: goals,
      bwTarget: bw.length == 2 ? bw : d.bwTarget,
    );
  }
}

/// One day's body measurements. A quick weigh-in fills only weight;
/// an InBody-style scan fills the rest.
class BodyEntry {
  String date;
  double? weight; // kg
  double? smm; // skeletal muscle mass, kg
  double? fatMass; // body fat mass, kg
  double? pbf; // percent body fat
  double? water; // total body water, L
  double? visceral; // visceral fat level
  double? bmr; // basal metabolic rate, kcal
  double? score; // InBody score
  double? waist; // cm
  String note;

  BodyEntry({
    required this.date,
    this.weight,
    this.smm,
    this.fatMass,
    this.pbf,
    this.water,
    this.visceral,
    this.bmr,
    this.score,
    this.waist,
    this.note = '',
  });

  double? get bodyFatPct {
    if (pbf != null) return pbf;
    if (weight != null && fatMass != null && weight! > 0) return fatMass! / weight! * 100;
    return null;
  }

  double? get leanMass => (weight != null && fatMass != null) ? weight! - fatMass! : null;

  double? bmi(double heightCm) {
    if (weight == null || heightCm <= 0) return null;
    final m = heightCm / 100;
    return weight! / (m * m);
  }

  bool get isEmpty => [weight, smm, fatMass, pbf, water, visceral, bmr, score, waist].every((v) => v == null);

  Map<String, dynamic> toJson() => {
        'date': date,
        if (weight != null) 'weight': weight,
        if (smm != null) 'smm': smm,
        if (fatMass != null) 'fat': fatMass,
        if (pbf != null) 'pbf': pbf,
        if (water != null) 'water': water,
        if (visceral != null) 'visceral': visceral,
        if (bmr != null) 'bmr': bmr,
        if (score != null) 'score': score,
        if (waist != null) 'waist': waist,
        if (note.isNotEmpty) 'note': note,
      };

  factory BodyEntry.fromJson(Map<dynamic, dynamic> j) => BodyEntry(
        date: js(j['date']),
        weight: jd(j['weight']),
        smm: jd(j['smm']),
        fatMass: jd(j['fat']),
        pbf: jd(j['pbf']),
        water: jd(j['water']),
        visceral: jd(j['visceral']),
        bmr: jd(j['bmr']),
        score: jd(j['score']),
        waist: jd(j['waist']),
        note: js(j['note']),
      );
}

class CheckIn {
  String sleep;
  String pain;
  String notes;
  CheckIn({this.sleep = '', this.pain = '', this.notes = ''});
  Map<String, dynamic> toJson() => {'sleep': sleep, 'pain': pain, 'notes': notes};
  factory CheckIn.fromJson(Map<dynamic, dynamic> j) =>
      CheckIn(sleep: js(j['sleep']), pain: js(j['pain']), notes: js(j['notes']));
}

/// Gym setup: bar, available plates, collars and rest timer defaults.
class GymPrefs {
  double bar;
  List<double> plates;
  bool collars; // competition collars, 2.5 kg each
  int restMain; // seconds, competition lifts and their variations
  int restAccessory; // seconds
  bool autoRest; // start the rest timer when a set gets a white light

  GymPrefs({
    this.bar = 20,
    List<double>? plates,
    this.collars = false,
    this.restMain = 180,
    this.restAccessory = 90,
    this.autoRest = true,
  }) : plates = plates ?? [25, 20, 15, 10, 5, 2.5, 1.25];

  double get collarKg => collars ? 5 : 0;

  Map<String, dynamic> toJson() => {
        'bar': bar,
        'plates': plates,
        'collars': collars,
        'restMain': restMain,
        'restAcc': restAccessory,
        'autoRest': autoRest,
      };

  factory GymPrefs.fromJson(Map<dynamic, dynamic> j) {
    final plates = [for (final x in jl(j['plates'])) jd(x)].whereType<double>().toList();
    return GymPrefs(
      bar: jd(j['bar']) ?? 20,
      plates: plates.isEmpty ? null : plates,
      collars: j['collars'] == true,
      restMain: ji(j['restMain']) ?? 180,
      restAccessory: ji(j['restAcc']) ?? 90,
      autoRest: j['autoRest'] != false,
    );
  }
}
