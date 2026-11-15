// Progress tab: estimated total with IPF GL points, then one card per lift.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tools_screen.dart';
import '../../l10n/l10n.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final prog = store.active;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          eyebrow: prog == null ? 'NO PROGRAM' : prog.name.toUpperCase(),
          title: 'PROGRESS',
          actions: [
            IconButton(
              tooltip: 'Plate and GL calculators',
              icon: Icon(Icons.calculate_outlined, color: Palette.of(context).onNavy),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToolsScreen())),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              const TotalCard(),
              const SizedBox(height: 12),
              const WeekLoadCard(),
              const SizedBox(height: 12),
              const RecordsCard(),
              const SizedBox(height: 12),
              for (final l in kLifts) ...[LiftCard(lift: l), const SizedBox(height: 12)],
              Text(
                'Estimated maxes come from the competition lifts you log (squat, bench, deadlift), '
                'counting RPE as reps left in the tank. Missed sets are ignored.',
                style: TextStyle(color: Palette.of(context).muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TotalCard extends StatelessWidget {
  const TotalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final pr = store.profile;
    final best = {for (final l in kLifts) l: store.bestOverall(l)};
    final complete = best.values.every((v) => v != null);
    final total = complete ? kLifts.map((l) => r25(best[l]!)).reduce((a, b) => a + b) : null;
    final startTotal = kLifts.map((l) => pr.maxes[l] ?? 0.0).reduce((a, b) => a + b);
    final goalTotal = kLifts.map((l) => pr.goals[l]?[0] ?? 0.0).reduce((a, b) => a + b);
    final bw = store.latestWeight;
    final meetBw = (pr.bwTarget[0] + pr.bwTarget[1]) / 2;
    final glNow = total == null ? null : store.gl(total, bw);
    final glStart = store.gl(startTotal, bw ?? meetBw);
    final glGoal = store.gl(goalTotal, meetBw);
    final cls = pr.weightClass.endsWith('+') ? pr.weightClass : '−${pr.weightClass}';
    final division = '${pr.equipped ? 'EQUIPPED' : 'CLASSIC'} · ${pr.female ? 'WOMEN' : 'MEN'} $cls';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ESTIMATED TOTAL · $division', style: eyebrowStyle(context, color: p.navyMuted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total == null ? '—' : fmt(total),
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, height: 1, color: p.onNavy, fontFeatures: kTabular)),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: T('kg', style: TextStyle(color: p.navyMuted, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  T('GL POINTS', style: eyebrowStyle(context, color: p.navyMuted)),
                  Text(glNow == null ? '—' : glNow.toStringAsFixed(1),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final l in kLifts)
              Expanded(
                child: Row(children: [
                  Container(width: 4, height: 28, color: p.lift(l)),
                  const SizedBox(width: 6),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(kLiftNames[l]!.toUpperCase(), style: eyebrowStyle(context, color: p.navyMuted)),
                    Text(best[l] == null ? '—' : fmt(r25(best[l]!)),
                        style: TextStyle(fontWeight: FontWeight.w800, color: p.onNavy, fontFeatures: kTabular)),
                  ]),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(30)),
          const SizedBox(height: 10),
          Text(
            'Start ${fmt(startTotal)} kg${glStart == null ? '' : ' (${glStart.toStringAsFixed(1)} GL)'}  ·  '
            'Goal ${fmt(goalTotal)} kg${glGoal == null ? '' : ' (${glGoal.toStringAsFixed(1)} GL at ${fmt1(meetBw)} kg)'}',
            style: TextStyle(color: p.navyMuted, fontSize: 12.5, fontFeatures: kTabular),
          ),
          if (bw == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: T('Log your bodyweight to see live GL points.', style: TextStyle(color: p.navyMuted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

class LiftCard extends StatelessWidget {
  final String lift;
  const LiftCard({super.key, required this.lift});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final weeks = store.active?.weeks ?? 8;
    final best = store.bestByWeek(lift);
    final m = store.profile.maxes[lift] ?? 0.0;
    final g = store.profile.goals[lift] ?? [m, m];
    final top = best.isEmpty ? null : best.values.reduce((a, b) => a > b ? a : b);
    double pct(double x) => g[1] - m == 0 ? 0 : ((x - m) / (g[1] - m)).clamp(0.0, 1.0).toDouble();
    final pts = (best.keys.toList()..sort()).map((w) => ChartPoint(w.toDouble(), best[w]!)).toList();
    final (lo, hi, step) = niceRange([m, g[1], ...pts.map((e) => e.y)], 5);
    final color = p.lift(lift);
    final everyOther = weeks > 10;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LiftTag(lift),
                  const SizedBox(height: 6),
                  T('BEST ESTIMATED MAX', style: eyebrowStyle(context)),
                ]),
              ),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: top == null ? '—' : fmt(r25(top)),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
                TextSpan(text: ' kg', style: TextStyle(fontSize: 14, color: p.muted, fontWeight: FontWeight.w600)),
              ]), style: const TextStyle(fontFeatures: kTabular)),
            ],
          ),
          if (top != null && r25(top) >= m + 2.5) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              decoration: BoxDecoration(
                color: p.ok.withAlpha(24),
                border: Border.all(color: p.ok.withAlpha(120)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.trending_up, color: p.ok, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Your estimated max is ${fmt(r25(top))} kg, above your ${fmt(m)} kg max.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Update your ${kLiftNames[lift]!.toLowerCase()} max to ${fmt(r25(top))} kg?',
                        body: 'Every % target for this lift goes up. RPE adjustments for it are cleared, '
                            'because the new max already includes them.',
                        action: 'Update max');
                    if (ok) store.updateMax(lift, r25(top));
                  },
                  child: const T('Update'),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 14, children: [
            _fact(context, 'Start', m),
            _fact(context, 'Target', g[0]),
            _fact(context, 'Stretch', g[1]),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 14,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 3,
                  child: Container(height: 8, decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(4))),
                ),
                Positioned(
                  left: 0,
                  top: 3,
                  child: Container(
                    width: c.maxWidth * (top == null ? 0 : pct(top)),
                    height: 8,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Positioned(left: c.maxWidth * pct(g[0]) - 1, top: 0, child: Container(width: 2, height: 14, color: p.ink)),
              ]),
            );
          }),
          const SizedBox(height: 10),
          LineChart(
            points: pts,
            xMin: 1,
            xMax: weeks.toDouble(),
            yMin: lo,
            yMax: hi,
            yStep: step,
            xLabels: [for (var i = 1; i <= weeks; i++) (!everyOther || i.isOdd) ? 'W$i' : ''],
            color: color,
            guides: [
              GuideLine(m, 'start', p.muted),
              GuideLine(g[1], fmt(g[1]), color.withAlpha(190)),
            ],
            emptyText: 'Log a ${kLiftNames[lift]!.toLowerCase()} session to start the line',
          ),
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String label, double v) {
    final p = Palette.of(context);
    return Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label '),
          TextSpan(text: fmt(v), style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
        ]),
        style: TextStyle(fontSize: 13, color: p.muted, fontFeatures: kTabular));
  }
}

/// Personal records across every program: best 1, 3 and 5 rep weights and best estimated max.
class RecordsCard extends StatelessWidget {
  const RecordsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    const cols = ['1RM', '3RM', '5RM', 'e1RM'];
    final data = {for (final l in kLifts) l: store.personalRecords(l)};
    final any = data.values.any((m) => m.values.any((v) => v != null));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('PERSONAL RECORDS', style: headingStyle(context, size: 18)),
          const SizedBox(height: 2),
          T('Heaviest weight for at least 1, 3 and 5 reps, from every program you have logged.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 74),
            for (final c in cols) Expanded(child: Text(c, textAlign: TextAlign.center, style: eyebrowStyle(context))),
          ]),
          const SizedBox(height: 6),
          for (final l in kLifts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 74, child: Align(alignment: Alignment.centerLeft, child: LiftTag(l))),
                for (final c in cols)
                  Expanded(
                    child: Column(children: [
                      Text(
                        data[l]![c] == null ? '—' : fmt(c == 'e1RM' ? r25(data[l]![c]!.kg) : data[l]![c]!.kg),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFeatures: kTabular),
                      ),
                      if (data[l]![c] != null)
                        Text(shortDate(data[l]![c]!.date), style: TextStyle(fontSize: 10.5, color: p.muted)),
                    ]),
                  ),
              ]),
            ),
          if (!any)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: T('Log squat, bench or deadlift sets and your records appear here.',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

/// This week's hard sets by area, compared with last week, plus fatigue warnings.
class WeekLoadCard extends StatelessWidget {
  const WeekLoadCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final w = store.week;
    final load = store.weekLoad(w);
    final areas = {...load.sets.keys, ...load.prevSets.keys}.toList()
      ..sort((a, b) => (load.sets[b] ?? 0).compareTo(load.sets[a] ?? 0));
    final most = [for (final a in areas) (load.sets[a] ?? 0) > (load.prevSets[a] ?? 0) ? (load.sets[a] ?? 0) : (load.prevSets[a] ?? 0)]
        .fold<int>(1, (a, b) => a > b ? a : b);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WEEK $w LOAD', style: headingStyle(context, size: 18)),
          const SizedBox(height: 2),
          T('Hard sets by area. The grey bar is last week. Change the week on the Program tab.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          if (areas.isEmpty)
            T('No sets logged this week yet.', style: TextStyle(color: p.muted, fontSize: 13)),
          for (final a in areas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 86, child: Text(a, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final now = load.sets[a] ?? 0, before = load.prevSets[a] ?? 0;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 8, width: c.maxWidth * now / most, color: p.navy == Palette.dark.navy ? p.blue : p.navy),
                      const SizedBox(height: 2),
                      Container(height: 4, width: c.maxWidth * before / most, color: p.line),
                    ]);
                  }),
                ),
                SizedBox(
                  width: 52,
                  child: Text('${load.sets[a] ?? 0} / ${load.prevSets[a] ?? 0}',
                      textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontFeatures: kTabular)),
                ),
              ]),
            ),
          for (final msg in load.warnings)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.warn.withAlpha(24),
                border: Border.all(color: p.warn.withAlpha(120)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: p.warn, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
              ]),
            ),
        ],
      ),
    );
  }
}
