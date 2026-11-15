// Unit tests for the plan math, templates and JSON round-trips. Run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:meet_prep_log/core/calc.dart';
import 'package:meet_prep_log/core/models.dart';
import 'package:meet_prep_log/core/templates.dart';

Map<String, double> get maxes => {'squat': 150, 'bench': 130, 'deadlift': 200};

Workout find(Program p, String id) => p.workouts.firstWhere((w) => w.id == id);

void main() {
  group('calc', () {
    test('plate math loads a 20 kg bar per side', () {
      expect(perSide(112.5), [25, 20, 1.25]);
      expect(perSide(200), [25, 25, 25, 15]);
      expect(perSide(20), isNull);
    });

    test('plate plan follows the gym setup', () {
      expect(perSide(100, bar: 20, collars: 5), [25, 10, 2.5]);
      final plan = platePlan(101, plates: [25, 20, 10, 5, 2.5]);
      expect(plan!.plates, [25, 10, 5]);
      expect(plan.leftover, closeTo(0.5, 1e-9));
    });

    test('warm-up ramp to 140', () {
      expect(warmups(140), [(20.0, '10'), (55.0, '5'), (85.0, '3'), (105.0, '2'), (120.0, '1')]);
    });

    test('estimated max counts reps in reserve', () {
      expect(estimatedMax('100', '10', '10'), closeTo(133.3, 0.1));
      expect(estimatedMax('140', '1', '10'), 140);
      expect(estimatedMax('', '5', ''), isNull);
      expect(estimatedMax('100', '15', ''), isNull);
    });

    test('IPF GL points match the published example', () {
      // 90 kg man, 700 kg classic total ≈ 93.06 GL.
      expect(glPoints(700, 90), closeTo(93.06, 0.05));
    });

    test('dates add across months', () {
      expect(addDays('2026-11-28', 7), '2026-12-05');
      expect(daysBetween('2026-11-10', '2026-11-17'), 7);
      expect(weekdayName('2026-11-10'), 'Tue');
    });

    test('number formatting', () {
      expect(fmt(112.50), '112.5');
      expect(fmtInt(9450), '9,450');
      expect(fmtDuration(72), '1 h 12 min');
    });
  });

  group('templates', () {
    test('meet prep week 1 squat is 5 × 5 at 112.5 kg', () {
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      final thu = find(p, 'w1-thu');
      expect(thu.date, '2026-11-12');
      final squat = thu.exercises.first;
      expect(squat.lift, 'squat');
      expect(squat.plan.length, 5);
      expect(squat.targetKg(squat.plan.first, maxes), 112.5);
    });

    test('meet prep week 7 deadlift starts with a top single at 190', () {
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      final dl = find(p, 'w7-sat').exercises.first;
      expect(dl.plan.first.label, 'Top single');
      expect(dl.targetKg(dl.plan.first, maxes), 190);
    });

    test('mock meet attempts', () {
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      final meet = find(p, 'w8-sat');
      final squat = meet.exercises.first;
      expect([for (final s in squat.plan) squat.targetKg(s, maxes)], [135, 145, 152.5]);
    });

    test('every template builds with dated workouts inside its weeks', () {
      for (final t in kTemplates) {
        final p = t.build('2026-11-10', t.weeks);
        expect(p.weeks, t.weeks);
        for (final w in p.workouts) {
          expect(w.week, inInclusiveRange(1, p.weeks));
          expect(daysBetween(p.start, w.date), inInclusiveRange((w.week - 1) * 7, w.week * 7 - 1));
        }
      }
    });

    test('custom program starts empty', () {
      final p = templateById('custom').build('2026-11-10', 6);
      expect(p.weeks, 6);
      expect(p.workouts, isEmpty);
    });
  });

  group('json', () {
    test('program round-trips with logs', () {
      final p = templateById('peak-10').build('2026-11-10', 10);
      final w = p.workouts.first;
      w.exercises.first.log = [LoggedSet(w: '110', r: '5', rpe: '7', status: 1)];
      w.durationMin = 75;
      w.bodyweight = 104.2;
      final back = Program.fromJson(p.toJson());
      expect(back.workouts.length, p.workouts.length);
      final b = back.workouts.first;
      expect(b.durationMin, 75);
      expect(b.bodyweight, 104.2);
      expect(b.exercises.first.log.first.status, 1);
      expect(b.exercises.first.plan.length, w.exercises.first.plan.length);
    });

    test('body entry derives body fat % and lean mass', () {
      final e = BodyEntry(date: '2026-11-10', weight: 104, fatMass: 20.8);
      expect(e.bodyFatPct, closeTo(20, 0.01));
      expect(e.leanMass, closeTo(83.2, 0.01));
      expect(e.bmi(185), closeTo(30.4, 0.1));
    });
  });
}
