// One workout: date, duration, bodyweight, every exercise with its sets, and
// controls to add, edit, reorder and remove exercises.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_editor.dart';

class WorkoutScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutScreen({super.key, required this.workoutId});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _tick;

  /// When the current rest ends (null = no rest running).
  final rest = ValueNotifier<DateTime?>(null);
  int restTotal = 0;

  void _startRest(int seconds) {
    restTotal = seconds;
    rest.value = DateTime.now().add(Duration(seconds: seconds));
  }

  @override
  void initState() {
    super.initState();
    // Refresh the running clock while the workout is live.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final w = store.workout(widget.workoutId);
    if (w == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This workout was deleted.')));
    }
    final prog = store.active!;
    final st = store.stats(w);
    final dur = store.durationOf(w);
    final k = '${w.id}-${store.revision}';

    return Scaffold(
      appBar: AppBar(
        title: Text(w.title),
        actions: [
          IconButton(
            tooltip: 'Start rest timer',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => _startRest(store.gym.restMain),
          ),
          PopupMenuButton<String>(
            tooltip: 'Workout options',
            onSelected: (v) => _menu(v, w),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'date', child: Text('Change date')),
              PopupMenuItem(value: 'copy', enabled: w.week < prog.weeks, child: Text('Copy to week ${w.week + 1}')),
              const PopupMenuItem(value: 'delete', child: Text('Delete workout')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<DateTime?>(
        valueListenable: rest,
        builder: (_, end, __) => end == null
            ? const SizedBox.shrink()
            : RestBar(
                end: end,
                total: restTotal,
                onAdjust: (sec) {
                  final next = end.add(Duration(seconds: sec));
                  if (next.isBefore(DateTime.now())) {
                    rest.value = null;
                  } else {
                    restTotal += sec;
                    rest.value = next;
                  }
                },
                onClose: () => rest.value = null,
              ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _menu('date', w),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: p.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${weekdayDate(w.date)} · Week ${w.week}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text('Change', style: TextStyle(color: p.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  if (w.timeHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 4),
                      child: Text(w.timeHint, style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: StatTile(
                              label: w.isLive ? 'Running' : 'Duration',
                              value: dur == null ? '—' : '$dur',
                              unit: dur == null ? '' : 'min')),
                      Expanded(child: StatTile(label: 'Sets', value: '${st.done}', unit: '/ ${st.planned}')),
                      Expanded(
                          child: StatTile(
                              label: 'Volume', value: st.volume > 0 ? fmtInt(st.volume) : '—', unit: st.volume > 0 ? 'kg' : '')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('$k-dur'),
                          initialValue: w.durationMin?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Duration (min)'),
                          onChanged: (v) => store.setDuration(w.id, v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('$k-bw'),
                          initialValue: w.bodyweight == null ? '' : fmt(w.bodyweight!),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Bodyweight (kg)',
                            hintText: store.latestWeight == null ? null : fmt(store.latestWeight!),
                          ),
                          onChanged: (v) => store.setWorkoutBodyweight(w.id, v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Bodyweight is also saved to the Body tab for this date.',
                      style: TextStyle(fontSize: 11.5, color: p.muted)),
                  const SizedBox(height: 12),
                  _lifecycle(context, store, p, w),
                ],
              ),
            ),
            if (w.note.isNotEmpty) ...[const SizedBox(height: 12), NoteBox(w.note)],
            const SizedBox(height: 12),
            for (var i = 0; i < w.exercises.length; i++) ...[
              Panel(
                padding: EdgeInsets.zero,
                child: ExerciseLogBlock(
                  workout: w,
                  slot: w.exercises[i],
                  index: i,
                  count: w.exercises.length,
                  onSetDone: (s) {
                    if (store.gym.autoRest) _startRest(store.restFor(s));
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add exercise'),
              onPressed: () => _addExercise(w),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('$k-notes'),
              initialValue: w.notes,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Session notes',
                hintText: 'Bar speed, technique, energy, anything that hurt',
              ),
              onChanged: (v) => store.setWorkoutNotes(w.id, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lifecycle(BuildContext context, AppStore store, Palette p, Workout w) {
    if (w.completed) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: p.ok),
          const SizedBox(width: 6),
          Expanded(child: Text('Completed', style: TextStyle(fontWeight: FontWeight.w800, color: p.ok))),
          TextButton(onPressed: () => store.reopenWorkout(w.id), child: const Text('Reopen')),
        ],
      );
    }
    if (w.isLive) {
      return Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: p.red, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Live · ${w.elapsedMin ?? 0} min',
                style: TextStyle(fontWeight: FontWeight.w800, color: p.red, fontFeatures: kTabular)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.flag, size: 18),
            label: const Text('Finish workout'),
            onPressed: () => store.finishWorkout(w.id),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Start workout'),
          onPressed: () => store.startWorkout(w.id),
        ),
        OutlinedButton(onPressed: () => store.finishWorkout(w.id), child: const Text('Mark as done')),
      ],
    );
  }

  Future<void> _menu(String v, Workout w) async {
    final store = StoreScope.read(context);
    if (v == 'rename') {
      final t = await promptText(context, title: 'Rename workout', label: 'Name', initial: w.title);
      if (t != null && t.trim().isNotEmpty) store.renameWorkout(w.id, t.trim());
    } else if (v == 'date') {
      final d = await pickIsoDate(context, w.date, help: 'Workout date');
      if (d != null) store.setWorkoutDate(w.id, d);
    } else if (v == 'copy') {
      final ok = store.copyWorkoutToNextWeek(w.id);
      if (mounted) toast(context, ok ? 'Copied to week ${w.week + 1}.' : 'This is the last week of the program.');
    } else if (v == 'delete') {
      final ok = await confirmDialog(context,
          title: 'Delete ${w.title}?',
          body: 'The workout and everything logged in it will be deleted.',
          action: 'Delete',
          danger: true);
      if (ok && mounted) {
        Navigator.of(context).pop();
        store.deleteWorkout(w.id);
      }
    }
  }

  Future<void> _addExercise(Workout w) async {
    final store = StoreScope.read(context);
    final def = await pickExercise(context);
    if (def == null || !mounted) return;
    final later = store.laterSameTitle(w).length;
    final cfg = await Navigator.of(context).push<SlotConfig>(
      MaterialPageRoute(builder: (_) => ExerciseConfigScreen(def: def, laterCount: later, workoutTitle: w.title)),
    );
    if (cfg == null) return;
    store.addExercise(w.id, cfg.toSlot(def), laterWeeks: cfg.laterWeeks);
  }
}

class ExerciseLogBlock extends StatelessWidget {
  final Workout workout;
  final ExerciseSlot slot;
  final int index;
  final int count;
  final void Function(ExerciseSlot s)? onSetDone;
  const ExerciseLogBlock(
      {super.key, required this.workout, required this.slot, required this.index, required this.count, this.onSetDone});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final maxes = store.profile.maxes;
    final s = slot;
    final n = math.max(s.plan.length, s.log.length);
    final weights = <double>[];
    for (final t in s.plan) {
      final kg = s.targetKg(t, maxes);
      if (kg != null && !weights.contains(kg)) weights.add(kg);
    }
    final textReps = s.plan.any((t) => !RegExp(r'^\d+$').hasMatch(t.reps));
    final k = '${workout.id}-${s.id}-${store.revision}';

    Widget field(int i, String f, String value, String hint, TextInputType kb) => Expanded(
          child: TextFormField(
            key: ValueKey('$k-$i-$f'),
            initialValue: value,
            keyboardType: kb,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: kTabular),
            decoration: InputDecoration(hintText: hint, fillColor: value.isNotEmpty ? p.surface : p.bg),
            onChanged: (v) => store.setSetValue(workout.id, s.id, i, f, v),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (s.lift != null) LiftTag(s.lift!),
                    Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                onSelected: (v) => _menu(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit sets and targets')),
                  PopupMenuItem(value: 'up', enabled: index > 0, child: const Text('Move up')),
                  PopupMenuItem(value: 'down', enabled: index < count - 1, child: const Text('Move down')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.summary(maxes), style: TextStyle(fontSize: 13, color: p.muted, fontFeatures: kTabular)),
                if (s.cue.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(s.cue, style: TextStyle(fontSize: 12.5, color: p.muted, fontStyle: FontStyle.italic)),
                ],
                if (s.barbell && weights.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 16, runSpacing: 6, children: [for (final kg in weights.take(3)) PlateLoad(kg)]),
                ],
                if (s.barbell && s.lift != null && weights.isNotEmpty && index == _firstLiftIndex(workout, s.lift!))
                  WarmupList(top: weights.first),
                const SizedBox(height: 10),
                Row(children: [
                  const SizedBox(width: 70),
                  for (final h in ['KG', 'REPS', 'RPE'])
                    Expanded(child: Center(child: Text(h, style: eyebrowStyle(context)))),
                  const SizedBox(width: 36),
                ]),
                const SizedBox(height: 4),
                for (var i = 0; i < n; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Builder(builder: (context) {
                      final t = i < s.plan.length ? s.plan[i] : PlannedSet();
                      final v = i < s.log.length ? s.log[i] : LoggedSet();
                      final label = t.label.isNotEmpty ? t.label : 'Set ${i + 1}';
                      final kg = s.targetKg(t, maxes);
                      return Row(children: [
                        SizedBox(
                          width: 70,
                          child: Text(label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: t.label.isNotEmpty ? FontWeight.w800 : FontWeight.w500,
                                color: t.label.isNotEmpty ? p.ink : p.muted,
                              )),
                        ),
                        field(i, 'w', v.w, kg == null ? 'kg' : fmt(kg), const TextInputType.numberWithOptions(decimal: true)),
                        const SizedBox(width: 6),
                        field(i, 'r', v.r, t.reps.isEmpty ? 'reps' : t.reps,
                            textReps ? TextInputType.text : TextInputType.number),
                        const SizedBox(width: 6),
                        field(i, 'rpe', v.rpe, t.rpe.isEmpty ? '–' : t.rpe,
                            const TextInputType.numberWithOptions(decimal: true)),
                        RefLight(
                          status: v.status,
                          onTap: () {
                            final wasUnmarked = v.status == 0;
                            store.cycleSetStatus(workout.id, s.id, i);
                            if (wasUnmarked) onSetDone?.call(s);
                          },
                        ),
                      ]);
                    }),
                  ),
                const SizedBox(height: 2),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      store.fillTargets(workout.id, s.id);
                    },
                    child: const Text('Fill targets'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      store.addLogRow(workout.id, s.id);
                    },
                    child: const Text('+ Set'),
                  ),
                  if (s.log.length > s.plan.length)
                    OutlinedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        store.removeLogRow(workout.id, s.id);
                      },
                      child: const Text('− Set'),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, String v) async {
    final store = StoreScope.read(context);
    if (v == 'up') {
      store.moveExercise(workout.id, slot.id, -1);
    } else if (v == 'down') {
      store.moveExercise(workout.id, slot.id, 1);
    } else if (v == 'edit') {
      final def = ExerciseDef(slot.defId, slot.name, '', barbell: slot.barbell, pctOf: slot.pctOf, lift: slot.lift);
      final cfg = await Navigator.of(context).push<SlotConfig>(
        MaterialPageRoute(
            builder: (_) => ExerciseConfigScreen(def: def, existing: slot, laterCount: 0, workoutTitle: workout.title)),
      );
      if (cfg == null) return;
      store.updateExercise(workout.id, slot.id, name: cfg.name, pctOf: cfg.pctOf, cue: cfg.cue, plan: cfg.plan);
    } else if (v == 'remove') {
      if (context.mounted) await _confirmRemove(context, store);
    }
  }

  Future<void> _confirmRemove(BuildContext context, AppStore store) async {
    final later = store.laterSameTitle(workout).where((x) => x.exercises.any((e) => e.id == slot.id)).length;
    var alsoLater = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Remove ${slot.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot.hasLog
                  ? 'The sets you logged for it in this workout will be deleted too.'
                  : 'It will be removed from this workout.'),
              if (later > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: alsoLater,
                  onChanged: (v) => setS(() => alsoLater = v ?? false),
                  title: Text('Also remove it from the $later later "${workout.title}" workout${later == 1 ? '' : 's'}'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.of(ctx).red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) store.removeExercise(workout.id, slot.id, laterWeeks: alsoLater);
  }
}

/// Index of the first exercise in the workout that trains this competition lift.
int _firstLiftIndex(Workout w, String lift) => w.exercises.indexWhere((e) => e.lift == lift);

/// Collapsible warm-up ramp to the first working weight.
class WarmupList extends StatelessWidget {
  final double top;
  const WarmupList({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final ramp = warmups(top, bar: store.gym.bar);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text('Warm-up to ${fmt(top)} kg',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.blue)),
        children: [
          for (final (kg, reps) in ramp)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 44, child: Text('× $reps', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: PlateLoad(kg)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Countdown shown at the bottom of a workout while resting.
class RestBar extends StatefulWidget {
  final DateTime end;
  final int total;
  final void Function(int seconds) onAdjust;
  final VoidCallback onClose;
  const RestBar({super.key, required this.end, required this.total, required this.onAdjust, required this.onClose});

  @override
  State<RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<RestBar> {
  Timer? _t;
  bool _alerted = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void didUpdateWidget(RestBar old) {
    super.didUpdateWidget(old);
    if (old.end != widget.end) _alerted = false;
  }

  void _onTick() {
    if (!mounted) return;
    final left = widget.end.difference(DateTime.now()).inSeconds;
    if (left <= 0 && !_alerted) {
      _alerted = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 350), HapticFeedback.heavyImpact);
      Future.delayed(const Duration(milliseconds: 700), HapticFeedback.vibrate);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final left = widget.end.difference(DateTime.now()).inSeconds + 1;
    final done = left <= 0;
    final frac = widget.total <= 0 ? 0.0 : (left / widget.total).clamp(0.0, 1.0).toDouble();
    return Material(
      color: done ? p.ok : p.navy,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: done ? 1 : frac,
              minHeight: 3,
              backgroundColor: Colors.white.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(done ? Colors.white : p.red),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(done ? 'REST DONE' : 'REST', style: eyebrowStyle(context, color: Colors.white70)),
                      Text(done ? 'Next set' : fmtClock(left),
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, fontFeatures: kTabular)),
                    ],
                  ),
                  const Spacer(),
                  if (!done) ...[
                    _btn('−30', () => widget.onAdjust(-30)),
                    _btn('+30', () => widget.onAdjust(30)),
                  ],
                  _btn(done ? 'OK' : 'Skip', widget.onClose),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(48, 40),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}
