import 'package:flutter_test/flutter_test.dart';
import 'package:meet_prep_log/core/calc.dart';
import 'package:meet_prep_log/core/predict.dart';

void main() {
  const today = '2026-11-16';
  final in4 = addDays(today, 28);

  // Best e1RM one per week, going up 1 kg a week: 150, 151, ... 157 today.
  final linear = [for (var i = 0; i < 8; i++) (date: addDays(today, -7 * i), kg: 157.0 - i)];

  test('needs at least 3 weekly bests over 2 weeks', () {
    expect(predictLift('squat', linear.take(2).toList(), today, in4), isNull);
    expect(
        predictLift('squat', [(date: today, kg: 150.0), (date: addDays(today, -1), kg: 149.0), (date: addDays(today, -2), kg: 148.0)],
            today, in4),
        isNull,
        reason: 'three sets in the same week are one weekly best');
  });

  test('a steady trend is followed, with gains slowing', () {
    final p = predictLift('squat', linear, today, in4)!;
    expect(p.now, closeTo(157, 0.01));
    expect(p.perWeek, closeTo(1.0, 0.01));
    // 4 weeks of +1 kg/week would be +4; slowing gives about +3.1.
    expect(p.kg, closeTo(160.15, 0.05));
    expect(p.low, closeTo(156.47, 0.05));
    expect(p.high, closeTo(163.82, 0.05));
    expect(p.weeks, 8);
    expect(p.confidence, 'good');
  });

  test('a flat trend stays flat', () {
    final flat = [for (var i = 0; i < 6; i++) (date: addDays(today, -7 * i), kg: 150.0)];
    final p = predictLift('bench', flat, today, in4)!;
    expect(p.kg, closeTo(150, 0.01));
    expect(p.perWeek.abs(), lessThan(0.001));
    expect(p.low, lessThan(150));
    expect(p.high, greaterThan(150));
    expect(p.confidence, 'medium');
  });

  test('unrealistic jumps are capped and the range stays useful', () {
    final jump = [(date: addDays(today, -14), kg: 100.0), (date: addDays(today, -7), kg: 120.0), (date: today, kg: 140.0)];
    final p = predictLift('deadlift', jump, today, in4)!;
    // Capped at 1.5% a week of the level (measured before the line is re-centred).
    expect(p.perWeek, lessThanOrEqualTo(p.now * 0.0155));
    expect(p.high - p.low, lessThan(p.kg * 0.25));
    expect(p.confidence, 'low');
  });

  test('logs older than 12 weeks and future dates are ignored', () {
    final noisy = [...linear, (date: addDays(today, -100), kg: 300.0), (date: addDays(today, 3), kg: 300.0)];
    final a = predictLift('squat', linear, today, in4)!;
    final b = predictLift('squat', noisy, today, in4)!;
    expect(b.kg, closeTo(a.kg, 1e-9));
  });

  test('the further ahead, the wider the range', () {
    final near = predictLift('squat', linear, today, addDays(today, 7))!;
    final far = predictLift('squat', linear, today, addDays(today, 84))!;
    expect(far.high - far.low, greaterThan(near.high - near.low));
    expect(far.kg, greaterThan(near.kg));
  });
}
