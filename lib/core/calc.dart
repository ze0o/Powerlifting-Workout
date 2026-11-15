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
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
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

String shortDate(String iso) {
  final d = parseIso(iso);
  return '${_months[d.month - 1]} ${d.day}';
}

String weekdayName(String iso) => _weekdays[parseIso(iso).weekday - 1];

String monthName(String iso) => _months[parseIso(iso).month - 1];

/// "Thu, Nov 12"
String weekdayDate(String iso) => '${weekdayName(iso)}, ${shortDate(iso)}';

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
