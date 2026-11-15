// Exercise picker (library + custom exercises) and the sets/targets editor.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/library.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../../l10n/l10n.dart';

/// What the editor returns.
class SlotConfig {
  final String name;
  final String? pctOf;
  final String cue;
  final List<PlannedSet> plan;
  final bool laterWeeks;
  const SlotConfig({required this.name, required this.pctOf, required this.cue, required this.plan, this.laterWeeks = false});

  ExerciseSlot toSlot(ExerciseDef def) => ExerciseSlot(
        id: uid(def.id),
        defId: def.id,
        name: name,
        lift: def.lift,
        pctOf: pctOf,
        barbell: def.barbell,
        cue: cue,
        plan: plan,
      );
}

// ======================================================================
// picker
// ======================================================================

Future<ExerciseDef?> pickExercise(BuildContext context) => showModalBottomSheet<ExerciseDef>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ExercisePicker(),
    );

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final query = q.trim().toLowerCase();
    final list = store.library.where((d) => query.isEmpty || d.name.toLowerCase().contains(query)).toList();
    final rows = <Widget>[];
    for (final cat in kCategories) {
      final items = list.where((d) => d.category == cat).toList();
      if (items.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(cat.toUpperCase(), style: eyebrowStyle(context)),
      ));
      for (final d in items) {
        rows.add(ListTile(
          dense: true,
          title: Text(tr(context, d.name), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (d.lift != null) 'Competition lift',
              if (d.pctOf != null && d.lift == null) '% of ${kLiftNames[d.pctOf]} max',
              if (d.barbell) 'Barbell',
              if (d.custom) 'Your exercise',
            ].join(' · '),
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
          trailing: d.custom
              ? IconButton(
                  tooltip: 'Delete from your exercises',
                  icon: Icon(Icons.delete_outline, color: p.muted, size: 20),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Delete ${d.name}?',
                        body: 'It is removed from your exercise list. Workouts that already use it keep it.',
                        action: 'Delete',
                        danger: true);
                    if (ok) store.deleteCustomExercise(d.id);
                  },
                )
              : null,
          onTap: () => Navigator.pop(context, d),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: T('ADD EXERCISE', style: headingStyle(context, size: 20)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search exercises'),
                onChanged: (v) => setState(() => q = v),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: p.red),
              title: Text(q.trim().isEmpty ? 'Create a new exercise' : 'Create "${q.trim()}"',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final d = await _createExercise(context, q.trim());
                if (d != null && context.mounted) Navigator.pop(context, d);
              },
            ),
            const Divider(),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text('No exercise matches "$q".', style: TextStyle(color: p.muted)))
                  : ListView(children: rows),
            ),
          ],
        ),
      ),
    );
  }
}

Future<ExerciseDef?> _createExercise(BuildContext context, String initial) async {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: initial);
  var category = 'Other';
  var barbell = false;
  String? pctOf;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const T('New exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(label: T('Name'), hintText: 'e.g. Pause bench with feet up'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(label: T('Category')),
                items: [for (final c in kCategories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setS(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: pctOf,
                decoration: const InputDecoration(label: T('Load as % of')),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: T('Nothing (I enter kg)')),
                  DropdownMenuItem<String?>(value: 'squat', child: T('Squat max')),
                  DropdownMenuItem<String?>(value: 'bench', child: T('Bench max')),
                  DropdownMenuItem<String?>(value: 'deadlift', child: T('Deadlift max')),
                ],
                onChanged: (v) => setS(() => pctOf = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const T('Barbell (show plates)'),
                value: barbell,
                onChanged: (v) => setS(() => barbell = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Create')),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return null;
  return store.addCustomExercise(name.text.trim(), category, barbell, pctOf);
}

// ======================================================================
// sets and targets editor
// ======================================================================

class _RowCtl {
  final TextEditingController load;
  final TextEditingController reps;
  final TextEditingController rpe;
  final String label;
  _RowCtl({String load = '', String reps = '', String rpe = '', this.label = ''})
      : load = TextEditingController(text: load),
        reps = TextEditingController(text: reps),
        rpe = TextEditingController(text: rpe);
  void dispose() {
    load.dispose();
    reps.dispose();
    rpe.dispose();
  }
}

class ExerciseConfigScreen extends StatefulWidget {
  final ExerciseDef def;
  final ExerciseSlot? existing;
  final int laterCount;
  final String workoutTitle;
  const ExerciseConfigScreen(
      {super.key, required this.def, this.existing, required this.laterCount, required this.workoutTitle});

  @override
  State<ExerciseConfigScreen> createState() => _ExerciseConfigScreenState();
}

class _ExerciseConfigScreenState extends State<ExerciseConfigScreen> {
  late final TextEditingController name;
  late final TextEditingController cue;
  final quickSets = TextEditingController(text: '3');
  final quickReps = TextEditingController(text: '8');
  final quickLoad = TextEditingController();
  final quickRpe = TextEditingController();
  final rows = <_RowCtl>[];
  late String mode; // 'kg' | 'pct'
  String? pctOf;
  bool later = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name = TextEditingController(text: e?.name ?? widget.def.name);
    cue = TextEditingController(text: e?.cue ?? '');
    pctOf = e?.pctOf ?? widget.def.pctOf;
    if (e != null) {
      mode = e.plan.any((s) => s.pct != null) ? 'pct' : 'kg';
      for (final s in e.plan) {
        final load = mode == 'pct'
            ? (s.pct == null ? '' : fmt(s.pct! * 100))
            : (s.kg == null ? '' : fmt(s.kg!));
        rows.add(_RowCtl(load: load, reps: s.reps, rpe: s.rpe, label: s.label));
      }
    } else {
      mode = 'kg';
      for (var i = 0; i < 3; i++) {
        rows.add(_RowCtl(reps: '8'));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, cue, quickSets, quickReps, quickLoad, quickRpe]) {
      c.dispose();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  double? get _max => pctOf == null ? null : StoreScope.read(context).profile.maxes[pctOf];

  void _switchMode(String m) {
    if (m == mode) return;
    final max = _max;
    for (final r in rows) {
      final v = parseNum(r.load.text);
      if (v == null || max == null || max <= 0) {
        r.load.text = '';
      } else if (m == 'pct') {
        r.load.text = fmt((v / max * 100 * 2).round() / 2);
      } else {
        r.load.text = fmt(r25(max * v / 100));
      }
    }
    setState(() {
      mode = m;
      if (m == 'pct') pctOf ??= 'squat';
    });
  }

  void _applyQuick() {
    final n = (int.tryParse(quickSets.text.trim()) ?? 0).clamp(1, 20).toInt();
    _disposeLater(List.of(rows));
    rows
      ..clear()
      ..addAll(List.generate(n, (_) => _RowCtl(load: quickLoad.text.trim(), reps: quickReps.text.trim(), rpe: quickRpe.text.trim())));
    setState(() {});
  }

  /// Controllers are disposed after the frame, once their text fields are gone.
  void _disposeLater(List<_RowCtl> old) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in old) {
        r.dispose();
      }
    });
  }

  void _save() {
    final plan = <PlannedSet>[];
    for (final r in rows) {
      final v = parseNum(r.load.text);
      plan.add(PlannedSet(
        pct: mode == 'pct' && v != null ? v / 100 : null,
        kg: mode == 'kg' ? v : null,
        reps: r.reps.text.trim(),
        rpe: r.rpe.text.trim(),
        label: r.label,
      ));
    }
    if (plan.isEmpty) {
      toast(context, 'Add at least one set.');
      return;
    }
    if (name.text.trim().isEmpty) {
      toast(context, 'Give the exercise a name.');
      return;
    }
    Navigator.pop(
      context,
      SlotConfig(
        name: name.text.trim(),
        pctOf: mode == 'pct' ? (pctOf ?? 'squat') : widget.def.pctOf,
        cue: cue.text.trim(),
        plan: plan,
        laterWeeks: later,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final store = StoreScope.of(context);
    final max = pctOf == null ? null : store.profile.maxes[pctOf];
    final loadLabel = mode == 'pct' ? '% MAX' : 'KG';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add exercise' : 'Edit sets'),
        actions: [
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const T('SAVE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            TextField(controller: name, decoration: const InputDecoration(label: T('Exercise name'))),
            const SizedBox(height: 16),
            T('LOAD', style: eyebrowStyle(context)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: T('Fixed kg')),
                ButtonSegment(value: 'pct', label: T('% of a max')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            if (mode == 'pct') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: pctOf ?? 'squat',
                decoration: InputDecoration(
                  label: T('Percent of'),
                  helperText: max == null ? null : 'Current max: ${fmt(max)} kg. Targets update when your max changes.',
                ),
                items: const [
                  DropdownMenuItem(value: 'squat', child: T('Squat max')),
                  DropdownMenuItem(value: 'bench', child: T('Bench max')),
                  DropdownMenuItem(value: 'deadlift', child: T('Deadlift max')),
                ],
                onChanged: (v) => setState(() => pctOf = v),
              ),
            ],
            const SizedBox(height: 16),
            Panel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T('QUICK FILL', style: eyebrowStyle(context)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _num(quickSets, 'Sets', TextInputType.number)),
                    const SizedBox(width: 6),
                    Expanded(child: _num(quickReps, 'Reps', TextInputType.text)),
                    const SizedBox(width: 6),
                    Expanded(child: _num(quickLoad, mode == 'pct' ? '%' : 'kg', const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 6),
                    Expanded(child: _num(quickRpe, 'RPE', const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _applyQuick, child: const T('Replace all sets')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const SizedBox(width: 56),
              for (final h in [loadLabel, 'REPS', 'RPE'])
                Expanded(child: Center(child: Text(h, style: eyebrowStyle(context)))),
              const SizedBox(width: 40),
            ]),
            const SizedBox(height: 4),
            for (var i = 0; i < rows.length; i++)
              Padding(
                key: ObjectKey(rows[i]),
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(
                    width: 56,
                    child: Text(rows[i].label.isNotEmpty ? rows[i].label : 'Set ${i + 1}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.muted, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: _cell(rows[i].load, const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 6),
                  Expanded(child: _cell(rows[i].reps, TextInputType.text)),
                  const SizedBox(width: 6),
                  Expanded(child: _cell(rows[i].rpe, const TextInputType.numberWithOptions(decimal: true))),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      tooltip: 'Remove set',
                      icon: Icon(Icons.remove_circle_outline, color: p.muted, size: 20),
                      onPressed: () => setState(() => _disposeLater([rows.removeAt(i)])),
                    ),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const T('Add set'),
                onPressed: () => setState(() {
                  final last = rows.isEmpty ? null : rows.last;
                  rows.add(_RowCtl(load: last?.load.text ?? '', reps: last?.reps.text ?? '', rpe: last?.rpe.text ?? ''));
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cue,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(label: T('Coaching cue (optional)'), hintText: 'e.g. Brace before every rep'),
            ),
            if (widget.existing == null && widget.laterCount > 0) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: later,
                onChanged: (v) => setState(() => later = v),
                title: Text('Also add to the ${widget.laterCount} later "${widget.workoutTitle}" workout${widget.laterCount == 1 ? '' : 's'}'),
                subtitle: const T('Same sets in every week. Edit any week afterwards.'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label, TextInputType kb) =>
      TextField(controller: c, keyboardType: kb, textAlign: TextAlign.center, decoration: InputDecoration(labelText: tr(context, label)));

  Widget _cell(TextEditingController c, TextInputType kb) => TextField(
        controller: c,
        keyboardType: kb,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: kTabular),
      );
}
