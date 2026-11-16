// Progress tab: where each lift is heading (in 4 weeks, or on meet day),
// with an 80% range, the trend per week, and how the goal compares.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/predict.dart';
import '../../core/store.dart';
import '../../l10n/l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';

class PredictionCard extends StatefulWidget {
  const PredictionCard({super.key});

  @override
  State<PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<PredictionCard> {
  bool meetDay = true;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final meet = store.currentMeet;
    final days = meet == null ? null : store.daysToMeet(meet);
    final hasMeet = meet != null && days != null && days >= 1;
    final useMeet = hasMeet && meetDay;
    final target = useMeet ? meet!.date : addDays(todayIso(), 28);
    final preds = {for (final l in kLifts) l: store.predict(l, target)};
    final total = store.predictTotal(target);
    final bw = (useMeet ? meet!.weighInKg : null) ?? store.latestWeight;
    final pts = (total == null || bw == null) ? null : store.points(total.total, bw);

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: T('PREDICTION', style: headingStyle(context, size: 18))),
          if (hasMeet)
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(tr(context, '4 weeks'))),
                ButtonSegment(value: true, label: Text(tr(context, 'Meet day'))),
              ],
              selected: {meetDay},
              onSelectionChanged: (s) => setState(() => meetDay = s.first),
            ),
        ]),
        const SizedBox(height: 2),
        Text(
          useMeet
              ? tr(context, '{meet} · {date} · in {n} days', {'meet': meet!.name, 'date': weekdayDate(target), 'n': days})
              : tr(context, '{date} · in 4 weeks', {'date': weekdayDate(target)}),
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: reduceMotion(context) ? Duration.zero : kMotion,
          child: Column(
            key: ValueKey(target),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in kLifts) ...[
                _LiftRow(lift: l, pred: preds[l], goal: store.profile.goals[l]?[0], max: store.profile.maxes[l]),
                const SizedBox(height: 14),
              ],
              if (total != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        T('PREDICTED TOTAL', style: eyebrowStyle(context, color: p.navyMuted)),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          CountUpText(r25(total.total),
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 3),
                            child: T('kg', style: TextStyle(color: p.navyMuted, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        Text(
                          tr(context, 'Likely {lo}–{hi} kg', {'lo': fmt(r25(total.low)), 'hi': fmt(r25(total.high))}),
                          style: TextStyle(color: p.navyMuted, fontSize: 12.5, fontFeatures: kTabular),
                        ),
                      ]),
                    ),
                    if (pts != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(tr(context, store.pointsName).toUpperCase(), style: eyebrowStyle(context, color: p.navyMuted)),
                        CountUpText(pts,
                            format: (v) => v.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                        Text(tr(context, 'at {bw} kg', {'bw': fmt1(bw!)}),
                            style: TextStyle(color: p.navyMuted, fontSize: 12)),
                      ]),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        T('From the best estimated max of each week over the last 12 weeks, counting recent weeks more, with gains slowing '
            'the further ahead it looks. The range covers 8 out of 10 likely outcomes. A good peak can beat it; a bad night '
            'of sleep or a missed cue can fall below it.',
            style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

class _LiftRow extends StatelessWidget {
  final String lift;
  final Prediction? pred;
  final double? goal;
  final double? max;
  const _LiftRow({required this.lift, required this.pred, required this.goal, required this.max});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final x = pred;
    if (x == null) {
      return Row(children: [
        LiftTag(lift),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tr(context, 'Log top sets for 3 different weeks to see a prediction.'),
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
        ),
      ]);
    }
    final g = goal;
    final (verdict, color) = g == null || g <= 0
        ? (null, p.muted)
        : g <= x.low
            ? ('On track for your goal', p.ok)
            : g <= x.kg
                ? ('Goal within reach', p.ok)
                : g <= x.high
                    ? ('Goal possible, not likely', p.warn)
                    : ('Goal is beyond the trend', p.red);
    final trend = x.perWeek;
    final trendText = '${trend >= 0 ? '+' : '−'}${fmt1(trend.abs())} ${tr(context, 'kg/week')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        LiftTag(lift),
        const SizedBox(width: 10),
        CountUpText(r25(x.kg), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFeatures: kTabular)),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 3, bottom: 2),
          child: T('kg', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(trendText,
              style: TextStyle(
                  color: trend >= 0 ? p.ok : p.warn, fontWeight: FontWeight.w700, fontSize: 12.5, fontFeatures: kTabular)),
          Text(tr(context, '{lo}–{hi} kg · {n} weeks', {'lo': fmt(r25(x.low)), 'hi': fmt(r25(x.high)), 'n': x.weeks}),
              style: TextStyle(color: p.muted, fontSize: 12, fontFeatures: kTabular)),
        ]),
      ]),
      const SizedBox(height: 6),
      _RangeBar(pred: x, goal: g, max: max, color: p.lift(lift)),
      if (verdict != null) ...[
        const SizedBox(height: 4),
        Text(
          '${tr(context, verdict)} · ${tr(context, 'goal {g} kg', {'g': fmt(g!)})}',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ]);
  }
}

/// A track with the likely range shaded, a dot for the prediction, a thin line
/// for the entered max and a flag for the goal. Grows in when first shown.
class _RangeBar extends StatelessWidget {
  final Prediction pred;
  final double? goal;
  final double? max;
  final Color color;
  const _RangeBar({required this.pred, required this.goal, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final values = [pred.low, pred.high, pred.now, if (goal != null && goal! > 0) goal!, if (max != null && max! > 0) max!];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * 0.12 + 2.5;
    lo -= pad;
    hi += pad;
    double at(double v, double w) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0) * w;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion(context) ? Duration.zero : kMotionSlow,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        double x(double v) => rtl ? w - at(v, w) : at(v, w);
        final mid = x(pred.kg);
        final a = x(pred.low), b = x(pred.high);
        final left = mid - (mid - (a < b ? a : b)) * t;
        final right = mid + ((a > b ? a : b) - mid) * t;
        return SizedBox(
          height: 22,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 9,
              child: Container(height: 4, decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(2))),
            ),
            Positioned(
              left: left,
              width: (right - left).clamp(0.0, w),
              top: 7,
              child: Container(
                height: 8,
                decoration: BoxDecoration(color: color.withAlpha(90), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (max != null && max! > 0)
              Positioned(left: x(max!) - 1, top: 4, child: Container(width: 2, height: 14, color: p.muted)),
            if (goal != null && goal! > 0)
              Positioned(left: x(goal!) - 7, top: -2, child: Icon(Icons.flag, size: 14, color: p.ink)),
            Positioned(
              left: mid - 6,
              top: 5,
              child: Opacity(
                opacity: t,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 2)),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
