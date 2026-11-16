// Progress prediction: where a lift's max is heading, from the lifter's own logs.
//
// Method (kept simple and honest, so it can be explained in one paragraph):
// 1. Take the best estimated max (e1RM) of each 7-day block over the last 12 weeks.
// 2. Fit a straight line through those points, counting recent weeks more
//    (a point's weight halves every 6 weeks).
// 3. Limit the weekly change to ±1.5% of the current level; faster than that is
//    almost always noise or a missed RPE.
// 4. Project forward with the gains slowing down (no lifter keeps a linear trend
//    forever): gain = slope × τ × (1 − e^(−days/τ)), with τ = 8 weeks.
// 5. The range is an 80% band from how far the weekly bests scatter around the
//    line (1.5–5% of the level), plus how uncertain the slope is, growing with distance.
import 'dart:math' as math;

import 'calc.dart';

/// One estimated max from the log.
typedef E1rmPoint = ({String date, double kg});

/// A forecast for one lift on one date.
class Prediction {
  final String lift;

  /// Today's level on the fitted trend (not the single best set).
  final double now;

  /// Predicted e1RM on [date], and its 80% range.
  final double kg;
  final double low;
  final double high;
  final String date;

  /// Trend at the moment, in kg per week.
  final double perWeek;

  /// How many weekly bests the trend is built on.
  final int weeks;

  const Prediction({
    required this.lift,
    required this.now,
    required this.kg,
    required this.low,
    required this.high,
    required this.date,
    required this.perWeek,
    required this.weeks,
  });

  /// 'low' (3–4 weeks), 'medium' (5–7) or 'good' (8+).
  String get confidence => weeks >= 8 ? 'good' : (weeks >= 5 ? 'medium' : 'low');
}

const _windowDays = 84;
const _halfLifeDays = 42.0;
const _tauDays = 56.0;
const _maxWeeklyChange = 0.015;
const _z80 = 1.2816;

/// Best e1RM in each 7-day block ending today, oldest first, as (days before today, kg).
List<(double, double)> weeklyBests(List<E1rmPoint> log, String today) {
  final best = <int, (double, double)>{};
  for (final p in log) {
    final age = daysBetween(p.date, today);
    if (age < 0 || age >= _windowDays || p.kg <= 0) continue;
    final block = age ~/ 7;
    final cur = best[block];
    if (cur == null || p.kg > cur.$2) best[block] = (age.toDouble(), p.kg);
  }
  final out = best.values.toList()..sort((a, b) => b.$1.compareTo(a.$1));
  return out;
}

/// Predicts a lift's e1RM on [target]. Returns null with fewer than 3 weekly
/// bests or when they span less than two weeks.
Prediction? predictLift(String lift, List<E1rmPoint> log, String today, String target) {
  final pts = weeklyBests(log, today);
  if (pts.length < 3) return null;
  final span = pts.first.$1 - pts.last.$1;
  if (span < 14) return null;

  // x = days relative to today (negative = past), weighted least squares.
  double sw = 0, sx = 0, sy = 0;
  for (final (age, kg) in pts) {
    final w = math.pow(0.5, age / _halfLifeDays).toDouble();
    sw += w;
    sx += w * -age;
    sy += w * kg;
  }
  final mx = sx / sw, my = sy / sw;
  double sxx = 0, sxy = 0;
  for (final (age, kg) in pts) {
    final w = math.pow(0.5, age / _halfLifeDays).toDouble();
    sxx += w * (-age - mx) * (-age - mx);
    sxy += w * (-age - mx) * (kg - my);
  }
  var slope = sxx == 0 ? 0.0 : sxy / sxx; // kg per day
  var level = my - slope * mx; // fitted value today (x = 0)

  final cap = level * _maxWeeklyChange / 7;
  if (slope.abs() > cap) {
    slope = slope.sign * cap;
    level = my - slope * mx;
  }

  // Scatter around the line (weighted), with a floor of 1.5% of the level:
  // e1RM from a single set is never more precise than that.
  double ss = 0;
  for (final (age, kg) in pts) {
    final w = math.pow(0.5, age / _halfLifeDays).toDouble();
    final r = kg - (level + slope * -age);
    ss += w * r * r;
  }
  final n = pts.length;
  final effectiveDf = math.max(1, n - 2);
  // Between 1.5% and 5% of the level: wilder scatter means the data (not the
  // lifter) is noisy, and an 80% range wider than ±10% helps nobody.
  final sd = math.sqrt(ss / sw * n / effectiveDf).clamp(level * 0.015, level * 0.05).toDouble();
  final slopeSe = math.min(sxx == 0 ? 0.0 : sd / math.sqrt(sxx), cap);

  final h = math.max(0, daysBetween(today, target)).toDouble();
  final grown = _tauDays * (1 - math.exp(-h / _tauDays)); // "effective days" of gain
  final kg = level + slope * grown;
  final spread = _z80 * math.sqrt(sd * sd * (1 + 1 / n) + math.pow(slopeSe * grown, 2));

  return Prediction(
    lift: lift,
    now: level,
    kg: kg,
    low: kg - spread,
    high: kg + spread,
    date: target,
    perWeek: slope * 7,
    weeks: n,
  );
}
