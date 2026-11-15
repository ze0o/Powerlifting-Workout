// Tools: plate calculator with warm-up ramp, and an IPF GL points calculator.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final weight = TextEditingController(text: '140');
  final bw = TextEditingController();
  final sq = TextEditingController();
  final bp = TextEditingController();
  final dl = TextEditingController();
  bool female = false;
  bool equipped = false;
  bool ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    final store = StoreScope.read(context);
    final pr = store.profile;
    female = pr.female;
    equipped = pr.equipped;
    final lw = store.latestWeight;
    bw.text = lw == null ? '' : fmt(lw);
    sq.text = fmt(pr.maxes['squat'] ?? 0);
    bp.text = fmt(pr.maxes['bench'] ?? 0);
    dl.text = fmt(pr.maxes['deadlift'] ?? 0);
    ready = true;
  }

  @override
  void dispose() {
    for (final c in [weight, bw, sq, bp, dl]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {String suffix = 'kg'}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final store = StoreScope.of(context);
    final w = parseNum(weight.text);
    final b = parseNum(bw.text);
    final lifts = [parseNum(sq.text), parseNum(bp.text), parseNum(dl.text)];
    final total = lifts.every((x) => x != null) ? lifts.fold<double>(0, (a, x) => a + x!) : null;
    final gl = (total != null && b != null) ? glPoints(total, b, female: female, equipped: equipped) : null;
    final dots = (total != null && b != null) ? dotsPoints(total, b, female: female) : null;
    final sameDivision = female == store.profile.female && equipped == store.profile.equipped;
    final cls = b == null ? null : _classFor(b, female);
    Standing? rank(String metric, double? v) =>
        (v == null || !sameDivision) ? null : (store.standingFor(metric, v, weightClass: cls) ?? store.standingFor(metric, v));
    final glRank = rank('gl', gl), totalRank = rank('total', total);

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PLATE CALCULATOR', style: headingStyle(context, size: 18)),
                  const SizedBox(height: 4),
                  Text(
                    'Uses your gym setup: ${fmt(store.gym.bar)} kg bar'
                    '${store.gym.collars ? ' with 2.5 kg collars' : ''}. Change it in the Athlete tab.',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  _field(weight, 'Weight on the bar'),
                  const SizedBox(height: 12),
                  if (w != null) PlateLoad(w),
                  if (w != null && w > store.gym.bar) ...[
                    const SizedBox(height: 14),
                    Text('WARM-UP TO ${fmt(w)} KG', style: eyebrowStyle(context)),
                    const SizedBox(height: 6),
                    for (final (kg, reps) in warmups(w, bar: store.gym.bar))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          SizedBox(width: 44, child: Text('× $reps', style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(child: PlateLoad(kg)),
                        ]),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('GL POINTS CALCULATOR', style: headingStyle(context, size: 18)),
                  const SizedBox(height: 4),
                  Text('The IPF formula that ranks lifters of different bodyweights against each other.',
                      style: TextStyle(color: p.muted, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Men')),
                      ButtonSegment(value: true, label: Text('Women')),
                    ],
                    selected: {female},
                    onSelectionChanged: (s) => setState(() => female = s.first),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Classic')),
                      ButtonSegment(value: true, label: Text('Equipped')),
                    ],
                    selected: {equipped},
                    onSelectionChanged: (s) => setState(() => equipped = s.first),
                  ),
                  const SizedBox(height: 12),
                  _field(bw, 'Bodyweight'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(sq, 'Squat')),
                    const SizedBox(width: 8),
                    Expanded(child: _field(bp, 'Bench')),
                    const SizedBox(width: 8),
                    Expanded(child: _field(dl, 'Deadlift')),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('TOTAL', style: eyebrowStyle(context, color: p.navyMuted)),
                          Text(total == null ? '—' : '${fmt(total)} kg',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('GL POINTS', style: eyebrowStyle(context, color: p.navyMuted)),
                        Text(gl == null ? '—' : gl.toStringAsFixed(2),
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                        Text('DOTS ${dots == null ? '—' : dots.toStringAsFixed(1)}',
                            style: TextStyle(color: p.navyMuted, fontWeight: FontWeight.w700, fontFeatures: kTabular)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text('WHERE YOU STAND', style: eyebrowStyle(context)),
                  const SizedBox(height: 4),
                  if (store.standing.isEmpty)
                    Text('Competition data isn\'t loaded yet. Connect to the internet, or ask the app owner to run '
                        'analysis/build_standing.py.', style: TextStyle(color: p.muted, fontSize: 12.5))
                  else if (!sameDivision)
                    Text('Rankings use your profile\'s sex and division. Switch the buttons back to see them.',
                        style: TextStyle(color: p.muted, fontSize: 12.5))
                  else ...[
                    for (final (label, r) in [('GL points', glRank), ('Total', totalRank)])
                      if (r != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _RankBar(label: label, standing: r),
                        ),
                    Text(store.standingSource, style: TextStyle(color: p.muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _classFor(double bw, bool female) {
  final limits = female ? kWomenClasses : kMenClasses;
  for (final c in limits) {
    if (c.endsWith('+')) return c;
    if (bw <= double.parse(c)) return c;
  }
  return limits.last;
}

class _RankBar extends StatelessWidget {
  final String label;
  final Standing standing;
  const _RankBar({required this.label, required this.standing});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final top = (100 - standing.pct).clamp(0.5, 100.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: top ${top < 10 ? fmt1(top) : top.round()}% of ${standing.label} (${fmtInt(standing.n)} lifters)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, c) {
        return Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(4))),
          Container(
            height: 8,
            width: c.maxWidth * (standing.pct / 100).clamp(0.0, 1.0).toDouble(),
            decoration: BoxDecoration(color: p.red, borderRadius: BorderRadius.circular(4)),
          ),
        ]);
      }),
    ]);
  }
}
