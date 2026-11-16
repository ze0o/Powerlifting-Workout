// Program tab: week strip and one card (box) per workout. Tap a card to open it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calc.dart';
import '../../core/cloud.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'program_picker.dart';
import 'coach_screen.dart';
import 'workout_screen.dart';
import '../../l10n/l10n.dart';
import '../motion.dart';

class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final prog = store.active;
    if (prog == null) return const _NoProgram();
    final w = store.week.clamp(1, prog.weeks).toInt();
    final (a, b) = store.weekRange(w);
    final list = store.workoutsInWeek(w);
    final label = prog.weekLabel(w);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(
          eyebrow: '${tr(context, prog.level.toUpperCase())} · ${tr(context, '{n} WEEKS', {'n': prog.weeks})}',
          title: prog.name.toUpperCase(),
          actions: [
            IconButton(
              tooltip: 'Weekly check-in',
              icon: Icon(Icons.assignment_outlined, color: p.onNavy),
              onPressed: () => showCheckinSheet(context),
            ),
          ],
          bottom: const WeekStrip(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tr(context, 'WEEK {n}', {'n': w})}${label.isNotEmpty ? ' · ${tr(context, label.toUpperCase())}' : ''}', style: headingStyle(context, size: 18)),
                    const SizedBox(height: 2),
                    Text('${shortDate(a)} – ${shortDate(b)} · ${tr(context, 'Workouts: {n}', {'n': list.length})}',
                        style: TextStyle(color: p.muted, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Week options',
                onSelected: (v) => _weekMenu(context, v, w),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'add', child: T('Add workout')),
                  PopupMenuItem(value: 'copy', enabled: w < prog.weeks, child: Text(tr(context, 'Copy this week to week {n}', {'n': w + 1}))),
                  const PopupMenuItem(value: 'checkin', child: T('Weekly check-in')),
                ],
              ),
            ],
          ),
        ),
        if (prog.adjustments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in prog.adjustments)
                InputChip(
                  avatar: Icon(a.kg > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16, color: a.kg > 0 ? p.ok : p.warn),
                  label: Text('${kLiftNames[a.lift]} ${a.kg > 0 ? '+' : '−'}${fmt(a.kg.abs())} kg from W${a.fromWeek}'),
                  tooltip: a.reason,
                  onDeleted: store.readOnly ? null : () async {
                    final ok = await confirmDialog(context,
                        title: 'Undo this change?',
                        body: '${a.reason}. Targets from week ${a.fromWeek} go back to your max.',
                        action: 'Undo');
                    if (ok) store.removeAdjustment(a.id);
                  },
                ),
            ]),
          ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Panel(child: T('No workouts this week yet. Add one, then add exercises to it.')),
          ),
        // Cards slide in when the week changes (keyed by week and workout).
        for (final (i, x) in list.indexed)
          FadeInUp(
            key: ValueKey('${prog.id}-$w-${x.id}'),
            index: i,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: WorkoutCard(workout: x),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const T('Add workout'),
              onPressed: () => addWorkoutDialog(context, w),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _weekMenu(BuildContext context, String v, int w) async {
    final store = StoreScope.read(context);
    if (v == 'add') {
      await addWorkoutDialog(context, w);
    } else if (v == 'copy') {
      final existing = store.workoutsInWeek(w + 1).length;
      if (existing > 0) {
        final ok = await confirmDialog(context,
            title: 'Copy week $w to week ${w + 1}?',
            body: 'Week ${w + 1} already has $existing workout${existing == 1 ? '' : 's'}. '
                'The copies are added next to them.',
            action: 'Copy');
        if (!ok) return;
      }
      final n = store.copyWeekToNext(w);
      if (context.mounted) toast(context, 'Copied $n workout${n == 1 ? '' : 's'} to week ${w + 1}.');
    } else if (v == 'checkin') {
      await showCheckinSheet(context);
    }
  }
}

class _NoProgram extends StatelessWidget {
  const _NoProgram();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ScreenHeader(eyebrow: 'GET STARTED', title: 'NO PROGRAM'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('Pick a program for your level, or build your own from scratch.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgramPickerScreen())),
                  child: const T('Choose a program'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final prog = store.active!;
    final now = store.currentWeekOf(prog);
    final started = daysBetween(prog.start, todayIso()) >= 0;
    return LayoutBuilder(builder: (context, c) {
      const gap = 4.0;
      final fit = (c.maxWidth - gap * (prog.weeks - 1)) / prog.weeks;
      final w = fit < 46 ? 46.0 : fit;
      final row = Row(
        children: [
          for (var i = 1; i <= prog.weeks; i++)
            Padding(
              padding: EdgeInsets.only(right: i < prog.weeks ? gap : 0),
              child: SizedBox(width: w, child: _weekBox(context, p, store, prog, i, started && now == i)),
            ),
        ],
      );
      return fit < 46 ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row) : row;
    });
  }

  Widget _weekBox(BuildContext context, Palette p, AppStore store, Program prog, int i, bool isNow) {
    final sel = store.week == i;
    final label = prog.weekLabel(i);
    return Material(
      color: sel ? Colors.white : Colors.white.withAlpha(16),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => store.selectWeek(i),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('W$i',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15, color: sel ? const Color(0xFF0C2340) : p.onNavy)),
                    FittedBox(
                      child: Text(label.isEmpty ? ' ' : label,
                          style: TextStyle(fontSize: 10.5, color: sel ? const Color(0xFF5A6678) : p.navyMuted)),
                    ),
                  ],
                ),
              ),
            ),
            if (isNow)
              Positioned(
                top: 4,
                right: 4,
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: p.red, shape: BoxShape.circle)),
              ),
          ],
        ),
      ),
    );
  }
}

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  const WorkoutCard({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final w = workout;
    final status = store.statusOf(w);
    final st = store.stats(w);
    final dur = store.durationOf(w);
    final bw = w.bodyweight ?? store.body[w.date]?.weight;
    final lifts = w.exercises.where((e) => e.lift != null).take(3).toList();
    final done = status == 'done';
    final cloud = CloudScope.of(context);
    final owner = store.readOnly ? store.ownerId : cloud.myId;
    final unread = owner == null ? 0 : cloud.unreadFor(athleteId: owner, programId: store.activeId, workoutId: w.id);

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => store.readOnly
                ? StoreScope(store: store, child: CoachWorkoutScreen(workoutId: w.id))
                : WorkoutScreen(workoutId: w.id))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 60,
                color: done ? p.navy : p.sunk,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(weekdayName(w.date).toUpperCase(),
                        style: eyebrowStyle(context, color: done ? p.navyMuted : p.muted)),
                    Text('${parseIso(w.date).day}',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900, height: 1.1, color: done ? p.onNavy : p.ink)),
                    Text(monthName(w.date).toUpperCase(), style: eyebrowStyle(context, color: done ? p.navyMuted : p.muted)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(tr(context, w.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            Badge(
                              label: Text('$unread'),
                              backgroundColor: p.red,
                              child: Icon(Icons.chat_bubble_outline, size: 18, color: p.muted),
                            ),
                          ],
                          const SizedBox(width: 8),
                          StatusChip(status),
                        ],
                      ),
                      if (w.timeHint.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(w.timeHint, style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ),
                      const SizedBox(height: 8),
                      if (lifts.isEmpty)
                        Text(
                          w.exercises.isEmpty
                              ? 'No exercises yet. Tap to add some.'
                              : w.exercises.take(3).map((e) => e.name).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      for (final s in lifts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              LiftTag(s.lift!),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s.summary(store.maxesFor(w)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontFeatures: kTabular)),
                              ),
                            ],
                          ),
                        ),
                      if (w.hasLog) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (dur != null) _meta(p, Icons.timer_outlined, w.isLive ? tr(context, '{n} min so far', {'n': dur}) : fmtDuration(dur)),
                            _meta(p, Icons.check_circle_outline, tr(context, '{a}/{b} sets', {'a': st.done, 'b': st.planned})),
                            if (st.volume > 0) _meta(p, Icons.fitness_center, '${fmtInt(st.volume)} kg'),
                            if (bw != null) _meta(p, Icons.monitor_weight_outlined, '${fmt(bw)} kg BW'),
                          ],
                        ),
                      ] else
                        Text(tr(context, 'Exercises: {a} · Sets: {b}', {'a': w.exercises.length, 'b': st.planned}),
                            style: TextStyle(fontSize: 12, color: p.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(Palette p, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.muted),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 12, color: p.ink, fontWeight: FontWeight.w600, fontFeatures: kTabular)),
        ],
      );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (text, color) = switch (status) {
      'done' => ('DONE', p.ok),
      'live' => ('LIVE', p.red),
      'logged' => ('LOGGED', p.blue),
      'missed' => ('NOT LOGGED', p.warn),
      _ => ('PLANNED', p.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status == 'live' || status == 'done' ? color : Colors.transparent,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(tr(context, text),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: spacing(context, 1),
              color: status == 'live' || status == 'done' ? Colors.white : color)),
    );
  }
}

Future<void> addWorkoutDialog(BuildContext context, int week) async {
  final store = StoreScope.read(context);
  final existing = store.workoutsInWeek(week);
  var date = existing.isEmpty ? store.weekRange(week).$1 : addDays(existing.last.date, 1);
  final ctl = TextEditingController();
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const T('Add workout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(label: T('Name'), hintText: 'e.g. Heavy Squat'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(weekdayDate(date)),
              onPressed: () async {
                final d = await pickIsoDate(ctx, date);
                if (d != null) setS(() => date = d);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Add')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final title = ctl.text.trim().isEmpty ? 'Workout' : ctl.text.trim();
  final w = store.addWorkout(week, title, date);
  if (context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workoutId: w.id)));
  }
}

// ---------- weekly check-in ----------

Future<void> showCheckinSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CheckinSheet(),
    );

class CheckinSheet extends StatelessWidget {
  const CheckinSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final w = store.week;
    final c = store.checkin(w);
    final text = store.checkinText(w);
    final k = 'ci-${store.activeId}-$w';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(tr(context, 'WEEK {n}', {'n': w}), style: eyebrowStyle(context)),
            const SizedBox(height: 2),
            T('WEEKLY CHECK-IN', style: headingStyle(context, size: 22)),
            const SizedBox(height: 4),
            T('Your logged workouts fill in automatically. Add sleep and anything that hurt, then copy it to your coach.',
                style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('$k-sleep'),
                  initialValue: c.sleep,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(label: T('Sleep, avg hours'), hintText: 'e.g. 6.5'),
                  onChanged: (v) => store.setCheckin(w, sleep: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey('$k-pain'),
                  initialValue: c.pain,
                  decoration: const InputDecoration(label: T('Pain or tightness'), hintText: 'e.g. left hip on squats'),
                  onChanged: (v) => store.setCheckin(w, pain: v),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              key: ValueKey('$k-notes'),
              initialValue: c.notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(label: T('Notes for the week'), hintText: 'Energy, technique, bar speed'),
              onChanged: (v) => store.setCheckin(w, notes: v),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const T('Copy check-in'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: store.checkinText(w)));
                  if (context.mounted) toast(context, 'Copied. Paste it into your chat with your coach.');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
