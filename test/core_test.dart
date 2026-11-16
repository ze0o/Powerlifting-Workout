// Unit tests for the plan math, templates and JSON round-trips. Run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:meet_prep_log/core/calc.dart';
import 'package:meet_prep_log/core/models.dart';
import 'package:meet_prep_log/core/store.dart';
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

  group('smart coaching', () {
    test('readiness score and suggested load', () {
      expect(Readiness(sleepHours: 8, energy: 5, soreness: 1, stress: 1).score, 100);
      final tired = Readiness(sleepHours: 5, energy: 2, soreness: 4, stress: 4);
      expect(tired.score, lessThan(35));
      expect(tired.suggestedScale, 0.90);
    });

    test('an easy top single raises next week\'s squat by 5 kg', () {
      final store = AppStore();
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      store.programs.add(p);
      store.activeId = p.id;
      final w5 = find(p, 'w5-thu');
      w5.exercises.first.log = [LoggedSet(w: '135', r: '1', rpe: '7')];
      final list = store.suggestAdjustments(w5);
      expect(list.length, 1);
      expect(list.first.lift, 'squat');
      expect(list.first.kg, 5);
      expect(list.first.fromWeek, 6);
      store.applyAdjustments(list);
      final w6 = find(p, 'w6-thu');
      final squat = w6.exercises.first;
      expect(squat.targetKg(squat.plan.first, store.maxesFor(w6)), 142.5);
      // The same workout doesn't suggest twice.
      expect(store.suggestAdjustments(w5), isEmpty);
    });

    test('a missed top single lowers the lift', () {
      final store = AppStore();
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      store.programs.add(p);
      store.activeId = p.id;
      final w5 = find(p, 'w5-tue');
      w5.exercises.first.log = [LoggedSet(w: '117.5', r: '0', status: 2)];
      final list = store.suggestAdjustments(w5);
      expect(list.single.kg, -5);
    });

    test('readiness load scale lowers % targets for that workout only', () {
      final store = AppStore();
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      store.programs.add(p);
      store.activeId = p.id;
      final w1 = find(p, 'w1-thu');
      w1.loadScale = 0.95;
      final squat = w1.exercises.first;
      expect(squat.targetKg(squat.plan.first, store.maxesFor(w1)), 107.5);
    });
  });

  group('competition', () {
    test('DOTS matches the published formula', () {
      // 480 kg total at 105 kg bodyweight, men.
      expect(dotsPoints(480, 105), closeTo(289.5, 0.3));
      expect(dotsPoints(0, 105), isNull);
    });

    test('percentile lookup', () {
      final cuts = [for (var i = 1; i <= 99; i++) i.toDouble()];
      expect(percentileOf(50, cuts), closeTo(50, 1e-9));
      expect(percentileOf(50.5, cuts), closeTo(50.5, 1e-9));
      expect(percentileOf(200, cuts), 99.5);
    });

    test('attempts from the entered max when there are no recent logs', () {
      final store = AppStore();
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      store.programs.add(p);
      store.activeId = p.id;
      final a = store.suggestAttempts('squat');
      expect(a.attempts, [137.5, 145, 152.5]);
    });

    test('meet total needs a good lift in all three', () {
      final m = Meet(id: 'm', name: 'Test', date: '2027-01-30');
      m.attempts['squat']![0] = Attempt(kg: '140', lights: [1, 1, 2]);
      m.attempts['bench']![0] = Attempt(kg: '120', lights: [1, 1, 1]);
      m.attempts['bench']![1] = Attempt(kg: '127.5', lights: [2, 2, 1]);
      expect(m.best('bench'), 120);
      expect(m.total, isNull);
      m.attempts['deadlift']![0] = Attempt(kg: '190', lights: [1, 2, 1]);
      expect(m.total, 450);
      final back = Meet.fromJson(m.toJson());
      expect(back.total, 450);
    });

    test('lining up moves the program meet day to the meet date', () {
      final store = AppStore();
      final p = templateById('meet-prep-8').build('2026-11-10', 8);
      store.programs.add(p);
      store.activeId = p.id;
      final m = Meet(id: 'm', name: 'Test', date: '2027-01-16');
      expect(store.programMeetDay(p)!.id, 'w8-sat');
      store.alignProgramToMeet(m);
      expect(store.programMeetDay(p)!.date, '2027-01-16');
      expect(store.alignment(m).deltaDays, 0);
    });
  });

  group('coach mode', () {
    test('a sent program keeps the plan and drops logs, moved to the new start', () {
      final src = templateById('meet-prep-8').build('2026-11-10', 8);
      final w = src.workouts.first;
      w.completed = true;
      w.durationMin = 70;
      w.notes = 'felt good';
      w.readiness = Readiness(sleepHours: 8);
      w.exercises.first.log = [LoggedSet(w: '140', r: '3', rpe: '8', status: 1)];
      src.adjustments.add(Adjustment(id: 'a', lift: 'squat', fromWeek: 3, kg: 5, reason: 'r', sourceWorkoutId: w.id));

      final sent = AppStore.planOnly(src, '2026-11-17');
      expect(sent.id, isNot(src.id));
      expect(sent.start, '2026-11-17');
      expect(sent.workouts.length, src.workouts.length);
      expect(sent.adjustments, isEmpty);
      final c = sent.workouts.first;
      expect(c.date, addDays(w.date, 7));
      expect(c.completed, isFalse);
      expect(c.durationMin, isNull);
      expect(c.notes, '');
      expect(c.readiness, isNull);
      expect(c.exercises.first.log, isEmpty);
      expect(c.exercises.first.plan.length, w.exercises.first.plan.length);
      expect(c.exercises.first.pctOf, w.exercises.first.pctOf);
    });

    test('the athlete adds a sent program and it uses their maxes', () {
      final coach = templateById('meet-prep-8').build('2026-11-10', 8);
      final json = AppStore.planOnly(coach, '2026-12-07').toJson();
      final athlete = AppStore(readOnly: true); // read-only so the test never touches storage
      athlete.profile.maxes['squat'] = 200;
      athlete.addAssignedProgram(json);
      expect(athlete.programs.length, 1);
      expect(athlete.active!.start, '2026-12-07');
      final w = athlete.active!.workouts.firstWhere((x) => x.exercises.any((e) => e.pctOf == 'squat'));
      final slot = w.exercises.firstWhere((e) => e.pctOf == 'squat');
      final set = slot.plan.firstWhere((s) => s.pct != null);
      expect(slot.targetKg(set, athlete.maxesFor(w)), r25(200 * set.pct!));
    });

    test('a viewer store is read-only and loads a snapshot', () {
      final owner = AppStore(readOnly: true);
      owner.addAssignedProgram(templateById('foundation-8').build('2026-11-10', 8).toJson());
      final v = AppStore.viewer(owner.toJson(), ownerId: 'u1');
      expect(v.readOnly, isTrue);
      expect(v.ownerId, 'u1');
      expect(v.loaded, isTrue);
      expect(v.active, isNotNull);
    });

    test('cloud rows parse', () {
      final l = CoachLink.fromJson({
        'id': 'l1',
        'coach_id': 'c',
        'athlete_id': 'a',
        'athlete_name': 'Ali',
        'athlete_class': '105',
        'athlete_synced_at': '2026-11-15T10:00:00Z',
      });
      expect(l.athleteName, 'Ali');
      expect(l.athleteSex, 'male');
      expect(l.athleteSyncedAt, isNotNull);
      final a = ProgramAssignment.fromJson({
        'id': 'x',
        'coach_id': 'c',
        'athlete_id': 'a',
        'program': {'name': 'Peak', 'weeks': 10, 'start': '2026-12-07'},
        'status': 'sent',
      });
      expect(a.programName, 'Peak');
      expect(a.weeks, 10);
      final c = CoachComment.fromJson({
        'id': 'k',
        'athlete_id': 'a',
        'author_id': 'c',
        'program_id': 'p',
        'workout_id': 'w1-mon',
        'body': 'Great depth',
        'created_at': '2026-11-15T10:00:00Z',
      });
      expect(c.readAt, isNull);
      expect(c.body, 'Great depth');
    });
  });

  group('federations and Wilks', () {
    test('Wilks matches published coefficients', () {
      // Original Wilks: coefficient 0.6086 at 100 kg (men).
      expect(wilksPoints(700, 100)!, closeTo(426.0, 0.1));
      expect(wilksPoints(700, 100, v2020: true)!, closeTo(510.6, 0.1));
      expect(wilksPoints(400, 60, female: true)!, closeTo(446.0, 0.1));
      expect(wilksPoints(400, 60, female: true, v2020: true)!, closeTo(527.6, 0.1));
      // Bodyweight is clamped to the fitted range.
      expect(wilksPoints(700, 250), wilksPoints(700, 201.9));
      expect(wilksPoints(0, 100), isNull);
    });

    test('scorePoints picks the formula', () {
      expect(scorePoints('gl', 600, 93), glPoints(600, 93));
      expect(scorePoints('dots', 600, 93), dotsPoints(600, 93));
      expect(scorePoints('wilks2020', 600, 93), wilksPoints(600, 93, v2020: true));
    });

    test('every federation has sorted classes ending in a + class', () {
      for (final f in kFederations) {
        for (final list in [f.men, f.women]) {
          expect(list.last.endsWith('+'), isTrue, reason: f.id);
          final limits = [for (final c in list.take(list.length - 1)) double.parse(c)];
          expect(limits, [...limits]..sort(), reason: f.id);
        }
        expect(kScoreFormulas, contains(f.score));
      }
      expect(federationById('usapl').women, contains('65'));
      expect(federationById('wrpf').women.last, '90+');
      expect(federationById('nope').id, 'ipf');
    });

    test('fitClass picks the lightest class that fits', () {
      final men = federationById('usapl').men;
      expect(fitClass(men, 105), '110');
      expect(fitClass(men, 82.5), '82.5');
      expect(fitClass(men, 150), '140+');
      expect(fitClass(kMenClasses, 100), '105');
    });

    test('profile keeps federation and formula through JSON', () {
      final p = Profile.defaults()
        ..federation = 'wrpf'
        ..weightClass = '110';
      final back = Profile.fromJson(p.toJson());
      expect(back.federation, 'wrpf');
      expect(back.scoreFormula, 'wilks');
      expect(back.score, '');
      final q = Profile.fromJson({...p.toJson(), 'score': 'dots'});
      expect(q.scoreFormula, 'dots');
      // Old backups have no federation: IPF and GL.
      final old = Profile.fromJson({'sex': 'male', 'class': '105'});
      expect(old.federation, 'ipf');
      expect(old.scoreFormula, 'gl');
    });
  });
}
