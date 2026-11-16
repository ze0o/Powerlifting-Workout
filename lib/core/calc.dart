// Pure helpers: number and date formatting, plate math, estimated max,
// IPF GL points and IPF weight classes. No Flutter imports.
import 'dart:math' as math;

const double kBar = 20;
const List<double> kPlates = [25, 20, 15, 10, 5, 2.5, 1.25];
const List<String> kLifts = ['squat', 'bench', 'deadlift'];
const Map<String, String> kLiftNames = {
  'squat': 'Squat',
  'bench': 'Bench',
  'deadlift': 'Deadlift',
};

/// IPF open weight classes (kg).
const List<String> kMenClasses = ['59', '66', '74', '83', '93', '105', '120', '120+'];
const List<String> kWomenClasses = ['47', '52', '57', '63', '69', '76', '84', '84+'];

// ---------- numbers ----------

String fmt(num v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

String fmt1(num v) => fmt((v * 10).round() / 10);

/// 9450 -> "9,450"
String fmtInt(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtDuration(int minutes) {
  final mn = dateLang == 'ar' ? 'د' : 'min', hr = dateLang == 'ar' ? 'س' : 'h';
  if (minutes < 60) return '$minutes $mn';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h $hr' : '$h $hr $m $mn';
}

double r25(double x) => (x / 2.5).round() * 2.5;

double? parseNum(String? s) {
  if (s == null) return null;
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

// ---------- dates (ISO yyyy-mm-dd, handled in UTC to avoid DST drift) ----------

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayIso() => isoDate(DateTime.now());

DateTime parseIso(String s) {
  try {
    final p = s.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  } catch (_) {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day);
  }
}

String addDays(String iso, int n) {
  final d = parseIso(iso);
  return isoDate(DateTime.utc(d.year, d.month, d.day + n));
}

int daysBetween(String from, String to) => parseIso(to).difference(parseIso(from)).inDays;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _weekdaysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// Language for month and weekday names: 'en' or 'ar'. Set by the app from its locale.
String dateLang = 'en';

String shortDate(String iso) {
  final d = parseIso(iso);
  return dateLang == 'ar' ? '${d.day} ${_monthsAr[d.month - 1]}' : '${_months[d.month - 1]} ${d.day}';
}

String weekdayName(String iso) => (dateLang == 'ar' ? _weekdaysAr : _weekdays)[parseIso(iso).weekday - 1];

String monthName(String iso) => (dateLang == 'ar' ? _monthsAr : _months)[parseIso(iso).month - 1];

/// "Thu, Nov 12" / "الخميس، 12 نوفمبر"
String weekdayDate(String iso) => '${weekdayName(iso)}${dateLang == 'ar' ? '،' : ','} ${shortDate(iso)}';

// ---------- lifting math ----------

/// Every plate size the gym setup can offer (kg).
const List<double> kAllPlates = [25, 20, 15, 10, 5, 2.5, 2, 1.5, 1.25, 1, 0.5, 0.25];

/// How to load a bar: plates for one side (heaviest first) and what's left over
/// per side when the available plates can't make the exact weight.
typedef PlatePlan = ({List<double> plates, double leftover});

PlatePlan? platePlan(double w, {double bar = kBar, List<double> plates = kPlates, double collars = 0}) {
  final base = bar + collars;
  if (w <= base) return null;
  var rem = (w - base) / 2;
  final sorted = [...plates]..sort((a, b) => b.compareTo(a));
  final out = <double>[];
  for (final p in sorted) {
    while (rem >= p - 1e-9) {
      out.add(p);
      rem -= p;
    }
  }
  return (plates: out, leftover: rem < 1e-6 ? 0.0 : rem);
}

/// Plates for one side of the bar, heaviest first. Null when the weight is the bar or less.
List<double>? perSide(double w, {double bar = kBar, List<double> plates = kPlates, double collars = 0}) =>
    platePlan(w, bar: bar, plates: plates, collars: collars)?.plates;

/// Warm-up ramp to a working weight: bar × 10, then 40/60/75/85% (rounded to 2.5 kg).
List<(double, String)> warmups(double top, {double bar = kBar}) {
  final out = <(double, String)>[(bar, '10')];
  for (final (pc, reps) in const [(.40, '5'), (.60, '3'), (.75, '2'), (.85, '1')]) {
    final w = r25(top * pc);
    if (w > out.last.$1 && w < top) out.add((w, reps));
  }
  return out;
}

/// Format seconds as m:ss.
String fmtClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Estimated 1RM (Epley), counting reps in reserve from RPE.
/// Null for missing values or sets outside 1–12 reps.
double? estimatedMax(String w, String r, String rpe) {
  final weight = parseNum(w), reps = parseNum(r);
  if (weight == null || reps == null || weight <= 0 || reps < 1 || reps > 12) return null;
  final p = parseNum(rpe);
  final rir = (p != null && p <= 10) ? math.max(0.0, 10 - p) : 0.0;
  final n = reps + rir;
  return n <= 1 ? weight : weight * (1 + n / 30);
}

/// IPF GL points: total × 100 / (A − B·e^(−C·bodyweight)).
double? glPoints(double total, double bodyweight, {bool female = false, bool equipped = false}) {
  if (total <= 0 || bodyweight <= 0) return null;
  final List<double> c;
  if (female) {
    c = equipped ? [758.63878, 949.31382, 0.02435] : [610.32796, 1045.59282, 0.03048];
  } else {
    c = equipped ? [1236.25115, 1449.21864, 0.01644] : [1199.72839, 1025.18162, 0.00921];
  }
  final bw = math.max(bodyweight, 40.0);
  return total * 100 / (c[0] - c[1] * math.exp(-c[2] * bw));
}

/// DOTS points: total × 500 / (a + b·bw + c·bw² + d·bw³ + e·bw⁴).
/// Bodyweight is held at 40–210 kg (men) or 40–150 kg (women).
double? dotsPoints(double total, double bodyweight, {bool female = false}) {
  if (total <= 0 || bodyweight <= 0) return null;
  final c = female
      ? [-57.96288, 13.6175032, -0.1126655495, 0.0005158568, -0.0000010706]
      : [-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093];
  final x = bodyweight.clamp(40.0, female ? 150.0 : 210.0).toDouble();
  final den = c[0] + c[1] * x + c[2] * x * x + c[3] * x * x * x + c[4] * x * x * x * x;
  return total * 500 / den;
}

/// Wilks points: total × 500 / polynomial (original, 1990s) or total × 600 /
/// polynomial (Wilks 2020). Bodyweight is held inside the range each formula was fitted on.
double? wilksPoints(double total, double bodyweight, {bool female = false, bool v2020 = false}) {
  if (total <= 0 || bodyweight <= 0) return null;
  final List<double> c;
  final double lo, hi, k;
  if (v2020) {
    c = female
        ? [-125.4255398, 13.71219419, -0.03307250631, -0.001050400051, 9.38773881462799e-06, -2.3334613884954e-08]
        : [47.46178854, 8.472061379, 0.07369410346, -0.001395833811, 7.07665973070743e-06, -1.20804336482315e-08];
    lo = 40;
    hi = female ? 150.95 : 200.95;
    k = 600;
  } else {
    c = female
        ? [594.31747775582, -27.23842536447, 0.82112226871, -0.00930733913, 4.731582e-05, -9.054e-08]
        : [-216.0475144, 16.2606339, -0.002388645, -0.00113732, 7.01863e-06, -1.291e-08];
    lo = female ? 26.51 : 40;
    hi = female ? 154.53 : 201.9;
    k = 500;
  }
  final x = bodyweight.clamp(lo, hi).toDouble();
  var den = 0.0;
  var xp = 1.0;
  for (final v in c) {
    den += v * xp;
    xp *= x;
  }
  return total * k / den;
}

// ---------- federations ----------

/// Score formulas a federation can use to rank lifters across classes.
const kScoreFormulas = ['gl', 'dots', 'wilks', 'wilks2020'];
const kScoreNames = {'gl': 'GL points', 'dots': 'DOTS', 'wilks': 'Wilks', 'wilks2020': 'Wilks 2020'};

/// A federation's weight classes and the formula it uses for best lifter.
class Federation {
  final String id;
  final String name;
  final List<String> men;
  final List<String> women;
  final String score;
  final String note;
  const Federation(this.id, this.name, this.men, this.women, this.score, this.note);

  List<String> classes(bool female) => female ? women : men;
}

const _traditionalMen = ['52', '56', '60', '67.5', '75', '82.5', '90', '100', '110', '125', '140', '140+'];

/// Classes and best-lifter formulas from each federation's current rulebook.
const kFederations = [
  Federation('ipf', 'IPF and affiliates', kMenClasses, kWomenClasses, 'gl',
      'IPF, Powerlifting America, British Powerlifting and other IPF members. Best lifter by IPF GL points.'),
  Federation('usapl', 'USAPL', _traditionalMen,
      ['44', '48', '52', '56', '60', '65', '70', '75', '82.5', '90', '100', '100+'], 'dots',
      'USA Powerlifting rulebook 2026: best lifter by DOTS.'),
  Federation('uspa', 'USPA / IPL', _traditionalMen,
      ['44', '48', '52', '56', '60', '67.5', '75', '82.5', '90', '100', '110', '110+'], 'dots',
      'USPA rulebook: placings by DOTS.'),
  Federation('wrpf', 'WRPF', _traditionalMen,
      ['44', '48', '52', '56', '60', '67.5', '75', '82.5', '90', '90+'], 'wilks',
      'WRPF rulebook: best lifter by Wilks.'),
];

Federation federationById(String id) =>
    kFederations.firstWhere((f) => f.id == id, orElse: () => kFederations.first);

/// The class a lifter fits in [classes]: the lightest class whose limit is at or
/// above [kg] (a bodyweight or an old class limit), or the top + class.
String fitClass(List<String> classes, double? kg) {
  if (kg == null) return classes[classes.length ~/ 2];
  for (final c in classes) {
    final lim = double.tryParse(c);
    if (lim != null && kg <= lim + 1e-9) return c;
  }
  return classes.last;
}

/// Points with the chosen formula ('gl', 'dots', 'wilks', 'wilks2020').
double? scorePoints(String formula, double total, double bodyweight, {bool female = false, bool equipped = false}) =>
    switch (formula) {
      'dots' => dotsPoints(total, bodyweight, female: female),
      'wilks' => wilksPoints(total, bodyweight, female: female),
      'wilks2020' => wilksPoints(total, bodyweight, female: female, v2020: true),
      _ => glPoints(total, bodyweight, female: female, equipped: equipped),
    };

/// Where a value sits in a sorted list of 99 percentile cut points (p1..p99).
/// Returns the share of lifters below it, 0–100.
double percentileOf(double value, List<double> cuts) {
  if (cuts.isEmpty) return 0;
  var i = 0;
  while (i < cuts.length && value >= cuts[i]) {
    i++;
  }
  if (i == 0) return value <= 0 ? 0 : (value / cuts.first).clamp(0.0, 1.0).toDouble();
  if (i >= cuts.length) return 99.5;
  final lo = cuts[i - 1], hi = cuts[i];
  final frac = hi > lo ? (value - lo) / (hi - lo) : 0.0;
  return i + frac; // between p_i and p_(i+1)
}
