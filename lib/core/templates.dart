// Program templates: Beginner, Intermediate, Advanced and Build Your Own.
// Starting a template creates a Program the lifter can then edit freely.
// Loads are stored as % of the competition maxes, so changing a max updates every target.
import 'calc.dart';
import 'library.dart';
import 'models.dart';

class ProgramTemplate {
  final String id;
  final String name;
  final String level; // Beginner | Intermediate | Advanced | Custom
  final String frequency;
  final int weeks;
  final bool customWeeks;
  final String summary;
  final String startHint;
  final Program Function(String start, int weeks) build;

  const ProgramTemplate({
    required this.id,
    required this.name,
    required this.level,
    required this.frequency,
    required this.weeks,
    required this.summary,
    required this.startHint,
    required this.build,
    this.customWeeks = false,
  });
}

const List<ProgramTemplate> kTemplates = [
  ProgramTemplate(
    id: 'foundation-8',
    name: 'Foundation',
    level: 'Beginner',
    frequency: '3 days / week',
    weeks: 8,
    summary: 'Squat, bench and deadlift practised often with 3 × 5 at rising percentages. '
        'Builds technique and a base before a first meet. Ends with a test week.',
    startHint: 'Pick your first training day. Workouts fall on day 1, 3 and 5 of each week (e.g. Sun, Tue, Thu).',
    build: _buildFoundation,
  ),
  ProgramTemplate(
    id: 'meet-prep-8',
    name: 'Meet Prep',
    level: 'Intermediate',
    frequency: '4 days + 1 optional',
    weeks: 8,
    summary: 'Upper/lower block with a squat focus, top singles from week 5 and a mock meet in week 8. '
        'For lifters who already train at RPE 7–8.',
    startHint: 'Start on a Tuesday (heavy bench). Then Thu, Fri, Sat and an optional Mon.',
    build: _buildMeetPrep,
  ),
  ProgramTemplate(
    id: 'peak-10',
    name: 'Peaking Block',
    level: 'Advanced',
    frequency: '4 days / week',
    weeks: 10,
    summary: 'Each lift trained twice a week: one heavy day, one volume variation. '
        'Volume, then strength, then peak and taper, ending on meet day.',
    startHint: 'Pick your first training day. Workouts fall on day 1, 3, 4 and 5 (e.g. Tue, Thu, Fri, Sat).',
    build: _buildPeak,
  ),
  ProgramTemplate(
    id: 'custom',
    name: 'Build Your Own',
    level: 'Custom',
    frequency: 'You choose',
    weeks: 8,
    customWeeks: true,
    summary: 'Start empty. Add workouts and exercises to week 1, then copy each week forward and adjust.',
    startHint: 'Pick the first day of week 1.',
    build: _buildCustom,
  ),
];

ProgramTemplate templateById(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return kTemplates[1];
}

// ---------- builders' helpers ----------

ExerciseSlot _ex(String defId, List<PlannedSet> plan, {String cue = '', String? name}) {
  final d = builtInDef(defId)!;
  return ExerciseSlot(
    id: defId,
    defId: defId,
    name: name ?? d.name,
    lift: d.lift,
    pctOf: d.pctOf,
    barbell: d.barbell,
    cue: cue,
    plan: plan,
  );
}

List<PlannedSet> _sets(int n, String reps, {double? pct, double? kg, String rpe = ''}) =>
    List.generate(n, (_) => PlannedSet(pct: pct, kg: kg, reps: reps, rpe: rpe));

List<PlannedSet> _top(double pct, {String rpe = '8'}) =>
    [PlannedSet(pct: pct, reps: '1', rpe: rpe, label: 'Top single')];

List<PlannedSet> _attempts() => [
      PlannedSet(pct: .90, reps: '1', label: '1st attempt'),
      PlannedSet(pct: .97, reps: '1', label: '2nd attempt'),
      PlannedSet(pct: 1.02, reps: '1', label: '3rd attempt'),
    ];

Workout _day(String id, int week, String start, int offset, String title, String hint, String note,
        List<ExerciseSlot> ex) =>
    Workout(
      id: id,
      week: week,
      title: title,
      timeHint: hint,
      date: addDays(start, (week - 1) * 7 + offset),
      note: note,
      exercises: ex,
    );

const _mockMeetNote = 'Squat, bench, deadlift in order, three attempts each, with competition commands. '
    'Only take the 3rd attempt if the 2nd moved well.';

// ---------- Beginner: Foundation (8 weeks, 3 days) ----------

const _fdLabels = ['70%', '72.5%', '75%', '77.5%', '80%', '82.5%', '85%', 'Test'];

Program _buildFoundation(String start, int weeks) {
  const pcts = [.70, .725, .75, .775, .80, .825, .85];
  final out = <Workout>[];
  for (var w = 1; w <= 7; w++) {
    final pc = pcts[w - 1];
    final note = w == 1
        ? 'Week 1: learn the movements. Every set should feel smooth (RPE 6–7). Same weight on every set.'
        : 'Three sets of five at the same weight. Stop the set if your form breaks.';
    out.add(_day('w$w-a', w, start, 0, 'Day A · Squat + Bench', '', note, [
      _ex('squat', _sets(3, '5', pct: pc, rpe: '7')),
      _ex('bench', _sets(3, '5', pct: pc, rpe: '7')),
      _ex('row', _sets(3, '8'), cue: 'Start light. Flat back, pull to your belly button.'),
      _ex('core', _sets(3, '30–45 s')),
    ]));
    out.add(_day('w$w-b', w, start, 2, 'Day B · Squat + Press + Deadlift', '', note, [
      _ex('squat', _sets(2, '5', pct: pc - .05, rpe: '6'), cue: 'Lighter squat day. Focus on depth and bracing.'),
      _ex('ohp', _sets(3, '5')),
      _ex('deadlift', _sets(2, '5', pct: pc, rpe: '7')),
      _ex('pullup', _sets(3, '8')),
    ]));
    out.add(_day('w$w-c', w, start, 4, 'Day C · Squat + Bench', '', note, [
      _ex('squat', _sets(3, '5', pct: pc, rpe: '7')),
      _ex('bench', _sets(3, '5', pct: pc, rpe: '7')),
      _ex('rdl', _sets(3, '8'), cue: 'Hips back, flat back, bar to mid-shin.'),
      _ex('curl', _sets(3, '12')),
    ]));
  }
  List<PlannedSet> test() => [
        PlannedSet(pct: .85, reps: '2', rpe: '7', label: 'Opener'),
        PlannedSet(pct: .95, reps: '1', rpe: '8–9', label: 'Heavy single'),
      ];
  const testNote = 'Test week. Warm up well, then work up to one heavy single at RPE 8–9. No grinders.';
  out.add(_day('w8-a', 8, start, 0, 'Test Day · Squat + Bench', '', testNote, [
    _ex('squat', test()),
    _ex('bench', test()),
  ]));
  out.add(_day('w8-b', 8, start, 2, 'Light Day', '', 'Easy day between tests.', [
    _ex('squat', _sets(2, '3', pct: .65, rpe: '5')),
    _ex('bench', _sets(2, '3', pct: .65, rpe: '5')),
  ]));
  out.add(_day('w8-c', 8, start, 4, 'Test Day · Deadlift', '', testNote, [
    _ex('deadlift', test()),
  ]));
  return Program(
    id: uid('p'),
    templateId: 'foundation-8',
    name: 'Foundation',
    level: 'Beginner',
    weeks: 8,
    start: start,
    weekLabels: _fdLabels,
    workouts: out,
  );
}

// ---------- Intermediate: Meet Prep (8 weeks, the plan built for Abdulaziz) ----------

const _mpLabels = ['75%', '80%', '85%', 'Deload', '90%', '92.5%', '95%', 'Meet'];

List<PlannedSet> _mpMain(int w) {
  switch (w) {
    case 1:
      return _sets(5, '5', pct: .75, rpe: '7–8');
    case 2:
      return _sets(5, '4', pct: .80, rpe: '7–8');
    case 3:
      return _sets(4, '3', pct: .85, rpe: '7–8');
    case 4:
      return _sets(3, '3', pct: .70, rpe: '5–6');
    case 5:
      return [..._top(.90), ..._sets(4, '3', pct: .85, rpe: '7–8')];
    case 6:
      return [..._top(.925), ..._sets(3, '3', pct: .875, rpe: '7–8')];
    default:
      return [..._top(.95), ..._sets(2, '2', pct: .90, rpe: '7–8')];
  }
}

Program _buildMeetPrep(String start, int weeks) {
  final out = <Workout>[];
  for (var w = 1; w <= 7; w++) {
    final deload = w == 4;
    int s(int n) => deload ? 2 : n;
    final note = deload
        ? 'Deload week: main lift at 70%. Do 2 sets of each accessory, about 20% lighter.'
        : (w >= 5
            ? 'Work up to the top single at RPE 8. If it feels like RPE 7 or easier, note it. Next week goes up.'
            : 'Stop each set with 1–2 reps left (RPE 7–8). Rest 3–4 min on the main lift.');
    out.add(_day('w$w-tue', w, start, 0, 'Heavy Bench', 'Tue · 9:30 – 10:45 PM', note, [
      _ex('bench', _mpMain(w)),
      _ex('ohp', _sets(s(3), '8')),
      _ex('dips', _sets(s(3), '8')),
      _ex('latraise', _sets(s(3), '15')),
      _ex('pushdown', _sets(s(3), '12')),
    ]));
    out.add(_day('w$w-thu', w, start, 2, 'Heavy Squat', 'Thu · 6:30 – 8:00 PM', note, [
      _ex('squat', _mpMain(w)),
      _ex('rdl', _sets(s(3), '8'), cue: 'New lift: start at 60–80 kg. Hips back, flat back, bar to mid-shin.'),
      _ex('legpress', _sets(s(4), '10', kg: 230, rpe: '8'), cue: '220–240 kg at RPE 8. Save the 260s for later.'),
      _ex('legcurl', _sets(s(3), '12')),
      _ex('core', _sets(s(3), '45–60 s')),
    ]));
    out.add(_day('w$w-fri', w, start, 3, 'Volume Bench + Back', 'Fri · 6:30 – 8:00 PM (gym closes 9)',
        'Volume day. Controlled reps, 2-second pause on every bench rep.', [
      _ex('pbench', _sets(s(4), '6', pct: .65, rpe: '7')),
      _ex('row', _sets(s(4), '8'), cue: 'New lift: start at 60–70 kg. Hinge to 45°, pull to your belly button.'),
      _ex('pullup', _sets(s(3), '10')),
      _ex('incline', _sets(s(3), '10')),
      _ex('facepull', _sets(s(3), '15')),
      _ex('curl', _sets(s(3), '12')),
    ]));
    out.add(_day('w$w-sat', w, start, 4, 'Heavy Deadlift + Squat', 'Sat · 6:30 – 8:00 PM', note, [
      _ex('deadlift', _mpMain(w)),
      _ex('deficit', _sets(s(3), '4', pct: .65, rpe: '7'), cue: 'Builds speed off the floor, where 220 stalled.'),
      _ex('psquat', _sets(s(3), '5', pct: .65, rpe: '7')),
      _ex('legext', _sets(s(3), '12–15')),
      _ex('bss', _sets(s(3), '8 / leg')),
      _ex('hlr', _sets(s(3), '12')),
    ]));
    out.add(_day('w$w-mon', w, start, 6, 'Conditioning + Weak Points', 'Mon · 9:30 – 10:15 PM (optional)',
        'Optional. Helps fat loss without tiring you for the main lifts.', [
      _ex('cond', _sets(1, '20 min'), cue: 'A pace where you can talk, but not comfortably.'),
      _ex('circuit', _sets(3, 'round')),
      _ex('core2', _sets(3, 'round')),
    ]));
  }
  out.add(_day('w8-tue', 8, start, 0, 'Heavy Bench', 'Tue · 9:30 – 10:45 PM',
      'Meet week. Keep everything light and fast. No accessories.', [
    _ex('bench', _sets(3, '3', pct: .70, rpe: '6')),
  ]));
  out.add(_day('w8-thu', 8, start, 2, 'Heavy Squat', 'Thu · 6:30 – 8:00 PM',
      'Meet week. Light squats only, then go home.', [
    _ex('squat', _sets(3, '2', pct: .70, rpe: '6')),
  ]));
  out.add(_day('w8-sat', 8, start, 4, 'Mock Meet', 'Sat · 6:30 PM', _mockMeetNote, [
    _ex('squat', _attempts(), name: 'Squat'),
    _ex('bench', _attempts(), name: 'Bench (pause on chest)'),
    _ex('deadlift', _attempts()),
  ]));
  return Program(
    id: uid('p'),
    templateId: 'meet-prep-8',
    name: 'Meet Prep',
    level: 'Intermediate',
    weeks: 8,
    start: start,
    weekLabels: _mpLabels,
    workouts: out,
  );
}

// ---------- Advanced: Peaking Block (10 weeks, 4 days) ----------

const _pkLabels = ['72.5%', '75%', '77.5%', 'Deload', '82.5%', '85%', '90%', '92.5%', '95%', 'Meet'];

List<PlannedSet> _pkHeavy(int w) {
  switch (w) {
    case 1:
      return _sets(4, '5', pct: .725, rpe: '7');
    case 2:
      return _sets(4, '5', pct: .75, rpe: '7–8');
    case 3:
      return _sets(5, '4', pct: .775, rpe: '7–8');
    case 4:
      return _sets(3, '3', pct: .65, rpe: '5–6');
    case 5:
      return _sets(4, '3', pct: .825, rpe: '7–8');
    case 6:
      return _sets(4, '3', pct: .85, rpe: '8');
    case 7:
      return [..._top(.90), ..._sets(3, '2', pct: .85, rpe: '7–8')];
    case 8:
      return [..._top(.925), ..._sets(2, '2', pct: .875, rpe: '7–8')];
    default:
      return [..._top(.95, rpe: '8–8.5'), ..._sets(2, '1', pct: .90, rpe: '7')];
  }
}

const List<(int, String, double)> _pkVolTable = [
  (4, '8', .625),
  (4, '7', .65),
  (4, '6', .675),
  (2, '5', .60),
  (4, '5', .70),
  (3, '5', .725),
  (3, '4', .725),
  (3, '3', .70),
  (2, '3', .65),
];

List<PlannedSet> _pkVol(int w) {
  final (n, reps, pc) = _pkVolTable[w - 1];
  return _sets(n, reps, pct: pc, rpe: w == 4 ? '5–6' : '7');
}

Program _buildPeak(String start, int weeks) {
  final out = <Workout>[];
  for (var w = 1; w <= 9; w++) {
    final light = w == 4 || w == 9;
    int s(int n) => light ? 2 : n;
    final note = w == 4
        ? 'Deload. Everything moves fast. Accessories 2 sets, lighter.'
        : w == 9
            ? 'Taper. Last heavy single, then keep everything crisp. Accessories 2 sets.'
            : (w <= 3
                ? 'Volume phase. Leave 2–3 reps in the tank on volume work.'
                : 'Strength phase. Heavy work at RPE 8 max. Log your top single honestly.');
    out.add(_day('w$w-d1', w, start, 0, 'Squat Heavy + Bench Volume', '', note, [
      _ex('squat', _pkHeavy(w)),
      _ex('spoto', _pkVol(w)),
      _ex('bss', _sets(s(3), '8 / leg')),
      _ex('facepull', _sets(s(3), '15')),
    ]));
    out.add(_day('w$w-d2', w, start, 2, 'Deadlift Heavy + Press', '', note, [
      _ex('deadlift', _pkHeavy(w)),
      _ex('ohp', _sets(s(3), '6')),
      _ex('row', _sets(s(4), '8')),
      _ex('hlr', _sets(s(3), '12')),
    ]));
    out.add(_day('w$w-d3', w, start, 3, 'Bench Heavy + Squat Volume', '', note, [
      _ex('bench', _pkHeavy(w)),
      _ex('psquat', _pkVol(w)),
      _ex('pullup', _sets(s(4), '8')),
      _ex('pushdown', _sets(s(3), '12')),
    ]));
    out.add(_day('w$w-d4', w, start, 4, 'Deadlift Volume + Bench Variation', '', note, [
      _ex('pdeadlift', _pkVol(w)),
      _ex('cgbench', _sets(s(3), '6', pct: .72, rpe: '7')),
      _ex('legcurl', _sets(s(3), '10')),
      _ex('core', _sets(s(3), '45 s')),
    ]));
  }
  out.add(_day('w10-d1', 10, start, 0, 'Openers · Squat + Bench', '',
      'Meet week. Singles at opener weight only. Leave feeling fresh.', [
    _ex('squat', _sets(2, '1', pct: .85, rpe: '6')),
    _ex('bench', _sets(2, '1', pct: .85, rpe: '6')),
  ]));
  out.add(_day('w10-d2', 10, start, 2, 'Openers · Deadlift', '', 'One or two easy singles. Then rest until meet day.', [
    _ex('deadlift', _sets(2, '1', pct: .80, rpe: '6')),
  ]));
  out.add(_day('w10-d4', 10, start, 4, 'Meet Day', '', _mockMeetNote, [
    _ex('squat', _attempts(), name: 'Squat'),
    _ex('bench', _attempts(), name: 'Bench (pause on chest)'),
    _ex('deadlift', _attempts()),
  ]));
  return Program(
    id: uid('p'),
    templateId: 'peak-10',
    name: 'Peaking Block',
    level: 'Advanced',
    weeks: 10,
    start: start,
    weekLabels: _pkLabels,
    workouts: out,
  );
}

// ---------- Custom ----------

Program _buildCustom(String start, int weeks) => Program(
      id: uid('p'),
      templateId: 'custom',
      name: 'My Program',
      level: 'Custom',
      weeks: weeks.clamp(1, 52).toInt(),
      start: start,
    );
