// Body tab: latest body composition (InBody-style), weight-class status,
// a chart per metric, and the full history. Quick weigh-ins and full scans share one list.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';

class Metric {
  final String key;
  final String label;
  final String unit;
  final int better; // 1 higher is better, -1 lower is better, 0 neutral
  final double? Function(BodyEntry e, double heightCm) read;
  const Metric(this.key, this.label, this.unit, this.better, this.read);
}

final List<Metric> kMetrics = [
  Metric('weight', 'Weight', 'kg', 0, (e, _) => e.weight),
  Metric('pbf', 'Body fat', '%', -1, (e, _) => e.bodyFatPct),
  Metric('smm', 'Skeletal muscle', 'kg', 1, (e, _) => e.smm),
  Metric('fat', 'Fat mass', 'kg', -1, (e, _) => e.fatMass),
  Metric('lean', 'Lean mass', 'kg', 1, (e, _) => e.leanMass),
  Metric('visceral', 'Visceral fat', 'level', -1, (e, _) => e.visceral),
  Metric('bmr', 'BMR', 'kcal', 1, (e, _) => e.bmr),
  Metric('water', 'Body water', 'L', 0, (e, _) => e.water),
  Metric('waist', 'Waist', 'cm', -1, (e, _) => e.waist),
  Metric('score', 'InBody score', '', 1, (e, _) => e.score),
  Metric('bmi', 'BMI', '', 0, (e, h) => e.bmi(h)),
];

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  String chart = 'weight';

  void _open(BuildContext context, [BodyEntry? e]) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BodyEntryScreen(existing: e)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final h = store.profile.heightCm;
    final entries = store.bodySorted;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: p.red,
        foregroundColor: Colors.white,
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const ScreenHeader(eyebrow: 'BODY COMPOSITION', title: 'BODY'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: entries.isEmpty ? _empty(context) : _content(context, store, p, entries, h),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOTHING LOGGED YET', style: headingStyle(context, size: 18)),
            const SizedBox(height: 6),
            const Text(
              'Add a morning weigh-in, or a full body-composition scan (InBody or similar): '
              'skeletal muscle, fat mass, body fat %, visceral fat, BMR and more. '
              'Bodyweight you enter in a workout also appears here.',
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _open(context), child: const Text('Add first entry')),
          ],
        ),
      );

  Widget _content(BuildContext context, AppStore store, Palette p, List<BodyEntry> entries, double h) {
    final latest = <Metric, MetricValue>{};
    for (final m in kMetrics) {
      final v = store.latestMetric((e) => m.read(e, h));
      if (v != null) latest[m] = v;
    }
    final available = kMetrics.where((m) => latest.containsKey(m)).toList();
    final chartMetric = available.firstWhere((m) => m.key == chart, orElse: () => available.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LATEST · ${weekdayDate(entries.last.date).toUpperCase()}', style: eyebrowStyle(context)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 520 ? 4 : (c.maxWidth > 300 ? 3 : 2);
                final tileW = (c.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final m in available)
                      SizedBox(
                        width: tileW,
                        child: StatTile(
                          label: m.label,
                          value: _val(m, latest[m]!.value),
                          unit: m.unit,
                          delta: _delta(m, latest[m]!),
                          deltaColor: _deltaColor(p, m, latest[m]!.delta),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _classPanel(context, store, p),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TREND', style: eyebrowStyle(context)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in available)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == chartMetric,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => chart = m.key),
                  ),
              ]),
              const SizedBox(height: 12),
              _chart(store, p, entries, chartMetric, h),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('HISTORY', style: eyebrowStyle(context)),
              const SizedBox(height: 4),
              for (final e in entries.reversed)
                InkWell(
                  onTap: () => _open(context, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      SizedBox(
                        width: 96,
                        child: Text(weekdayDate(e.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(
                          [
                            if (e.weight != null) '${fmt(e.weight!)} kg',
                            if (e.bodyFatPct != null) '${fmt1(e.bodyFatPct!)}% fat',
                            if (e.smm != null) 'SMM ${fmt1(e.smm!)}',
                            if (e.waist != null) 'waist ${fmt1(e.waist!)}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 13, fontFeatures: kTabular),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: p.muted),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _val(Metric m, double v) =>
      m.key == 'bmr' || m.key == 'score' || m.key == 'visceral' ? fmt(v.round()) : fmt1(v);

  String? _delta(Metric m, MetricValue v) {
    if (v.delta == null) return null;
    final d = v.delta!;
    if (d.abs() < 0.05) return 'no change';
    return '${d > 0 ? '+' : '−'}${_val(m, d.abs())} ${m.unit}'.trim();
  }

  Color? _deltaColor(Palette p, Metric m, double? d) {
    if (d == null || d.abs() < 0.05 || m.better == 0) return p.muted;
    return (d > 0) == (m.better > 0) ? p.ok : p.warn;
  }

  Widget _classPanel(BuildContext context, AppStore store, Palette p) {
    final pr = store.profile;
    final bw = store.latestWeight;
    final limit = pr.classLimit;
    final lo = pr.bwTarget[0], hi = pr.bwTarget[1];
    String status;
    Color color;
    if (bw == null) {
      status = 'Add a weigh-in to see where you stand.';
      color = p.muted;
    } else if (limit != null && bw > limit) {
      status = '${fmt1(bw - limit)} kg over the −${pr.weightClass} kg limit.';
      color = p.red;
    } else if (bw > hi) {
      status = '${fmt1(bw - hi)} kg above your meet range.';
      color = p.warn;
    } else if (bw < lo) {
      status = '${fmt1(lo - bw)} kg below your meet range.';
      color = p.blue;
    } else {
      status = 'Inside your meet range.';
      color = p.ok;
    }
    return Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEIGHT CLASS', style: eyebrowStyle(context)),
                const SizedBox(height: 2),
                Text(limit == null ? '${pr.weightClass} kg' : '−${pr.weightClass} kg',
                    style: headingStyle(context, size: 24)),
                const SizedBox(height: 4),
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('MEET RANGE', style: eyebrowStyle(context)),
              Text('${fmt(lo)}–${fmt(hi)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: kTabular)),
              const SizedBox(height: 6),
              Text('CURRENT', style: eyebrowStyle(context)),
              Text(bw == null ? '—' : '${fmt(bw)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: kTabular)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chart(AppStore store, Palette p, List<BodyEntry> entries, Metric m, double h) {
    final pts = <BodyEntry>[for (final e in entries) if (m.read(e, h) != null) e];
    if (pts.isEmpty) return const SizedBox.shrink();
    final first = pts.first.date;
    final lastDay = daysBetween(first, pts.last.date).toDouble();
    final span = lastDay < 7 ? 7.0 : lastDay;
    final values = [for (final e in pts) m.read(e, h)!];
    final isWeight = m.key == 'weight';
    final pr = store.profile;
    final unit = m.key == 'bmr' ? 50.0 : (values.reduce((a, b) => a > b ? a : b) > 40 ? 2.0 : 1.0);
    final (lo, hi, step) = niceRange([...values, if (isWeight) pr.bwTarget[0]], unit, unit: unit, minSpan: unit * 4);
    return LineChart(
      points: [for (var i = 0; i < pts.length; i++) ChartPoint(daysBetween(first, pts[i].date).toDouble(), values[i])],
      xMin: 0,
      xMax: span,
      yMin: lo,
      yMax: hi,
      yStep: step,
      xLabels: [shortDate(first), shortDate(addDays(first, span.round()))],
      color: p.navy == Palette.dark.navy ? p.blue : p.navy,
      band: isWeight ? (pr.bwTarget[0], pr.bwTarget[1], 'meet range') : null,
    );
  }
}

// ======================================================================
// add / edit an entry
// ======================================================================

class BodyEntryScreen extends StatefulWidget {
  final BodyEntry? existing;
  const BodyEntryScreen({super.key, this.existing});

  @override
  State<BodyEntryScreen> createState() => _BodyEntryScreenState();
}

class _BodyEntryScreenState extends State<BodyEntryScreen> {
  late String date;
  final c = <String, TextEditingController>{};
  final note = TextEditingController();

  static const _fields = [
    ('weight', 'Weight', 'kg'),
    ('waist', 'Waist', 'cm'),
    ('smm', 'Skeletal muscle mass', 'kg'),
    ('fat', 'Body fat mass', 'kg'),
    ('pbf', 'Percent body fat', '%'),
    ('water', 'Total body water', 'L'),
    ('visceral', 'Visceral fat level', ''),
    ('bmr', 'Basal metabolic rate', 'kcal'),
    ('score', 'InBody score', ''),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    date = e?.date ?? todayIso();
    final values = <String, double?>{
      'weight': e?.weight,
      'waist': e?.waist,
      'smm': e?.smm,
      'fat': e?.fatMass,
      'pbf': e?.pbf,
      'water': e?.water,
      'visceral': e?.visceral,
      'bmr': e?.bmr,
      'score': e?.score,
    };
    for (final f in _fields) {
      final v = values[f.$1];
      c[f.$1] = TextEditingController(text: v == null ? '' : fmt(v));
    }
    note.text = e?.note ?? '';
  }

  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    note.dispose();
    super.dispose();
  }

  double? _n(String k) => parseNum(c[k]!.text);

  void _save() {
    final store = StoreScope.read(context);
    final e = BodyEntry(
      date: date,
      weight: _n('weight'),
      waist: _n('waist'),
      smm: _n('smm'),
      fatMass: _n('fat'),
      pbf: _n('pbf'),
      water: _n('water'),
      visceral: _n('visceral'),
      bmr: _n('bmr'),
      score: _n('score'),
      note: note.text.trim(),
    );
    if (e.isEmpty) {
      toast(context, 'Enter at least one measurement.');
      return;
    }
    if (e.weight != null && (e.weight! < 30 || e.weight! > 300)) {
      toast(context, 'Weight should be in kg, for example 104.6.');
      return;
    }
    final clash = store.body[date];
    if (clash != null && widget.existing?.date != date) {
      // Merge into the entry that already exists for that day.
      e.weight ??= clash.weight;
      e.waist ??= clash.waist;
      e.smm ??= clash.smm;
      e.fatMass ??= clash.fatMass;
      e.pbf ??= clash.pbf;
      e.water ??= clash.water;
      e.visceral ??= clash.visceral;
      e.bmr ??= clash.bmr;
      e.score ??= clash.score;
    }
    store.upsertBody(e, previousDate: widget.existing?.date);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final ok = await confirmDialog(context,
        title: 'Delete this entry?', body: '${weekdayDate(date)} will be removed.', action: 'Delete', danger: true);
    if (ok && mounted) {
      store.deleteBody(widget.existing!.date);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final w = parseNum(c['weight']!.text), fat = parseNum(c['fat']!.text);
    final autoPbf = (w != null && fat != null && w > 0 && c['pbf']!.text.trim().isEmpty) ? fat / w * 100 : null;

    Widget field((String, String, String) f) => TextField(
          controller: c[f.$1],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: f.$2,
            suffixText: f.$3.isEmpty ? null : f.$3,
            helperText: f.$1 == 'pbf' && autoPbf != null ? 'Leave empty: ${fmt1(autoPbf)}% from fat mass' : null,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New body entry' : 'Edit body entry'),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(weekdayDate(date)),
              onPressed: () async {
                final d = await pickIsoDate(context, date, help: 'Measurement date');
                if (d != null) setState(() => date = d);
              },
            ),
            const SizedBox(height: 16),
            Text('SCALE', style: eyebrowStyle(context)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: field(_fields[0])),
              const SizedBox(width: 10),
              Expanded(child: field(_fields[1])),
            ]),
            const SizedBox(height: 20),
            Text('BODY COMPOSITION SCAN (OPTIONAL)', style: eyebrowStyle(context)),
            const SizedBox(height: 4),
            Text('Copy the numbers from your InBody (or similar) printout.', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            for (var i = 2; i < _fields.length; i += 2) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: field(_fields[i])),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < _fields.length ? field(_fields[i + 1]) : const SizedBox.shrink()),
              ]),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            TextField(
              controller: note,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes', hintText: 'e.g. after travel, morning fasted'),
            ),
          ],
        ),
      ),
    );
  }
}
