// Coach mode: the Coach tab (code and athlete list), one athlete's data (read-only,
// reusing the Program, Progress and Body screens), a read-only workout with comments,
// and sending a program to an athlete.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calc.dart';
import '../../core/cloud.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_screen.dart' show timeAgo;
import 'body_screen.dart';
import 'program_screen.dart';
import 'progress_screen.dart';

String _athleteName(BuildContext context, CoachLink l) =>
    l.athleteName.trim().isEmpty ? tr(context, 'Unnamed lifter') : l.athleteName.trim();

String _coachName(BuildContext context, CloudSync cloud, String coachId) {
  for (final l in cloud.coaches) {
    if (l.coachId == coachId && l.coachName.trim().isNotEmpty) return l.coachName.trim();
  }
  return tr(context, 'Your coach');
}

/// Shareable message with the coach code.
String coachInvite(BuildContext context, String code) => tr(context,
    'Join me on Meet Prep Log: open the Athlete tab, tap Connect to a coach and enter the code {code}.', {'code': code});

// ======================================================================
// Coach tab
// ======================================================================

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final p = Palette.of(context);
    final code = cloud.coachCode ?? '';
    return RefreshIndicator(
      onRefresh: cloud.refreshCoach,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            eyebrow: 'COACH MODE',
            title: 'ATHLETES',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh, color: p.onNavy),
                onPressed: cloud.refreshCoach,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    T('YOUR COACH CODE', style: eyebrowStyle(context)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: SelectableText(
                          code.isEmpty ? '······' : code,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6, fontFeatures: kTabular),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy invite',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: code.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: coachInvite(context, code)));
                                if (context.mounted) toast(context, 'Invite copied. Send it to your athlete.');
                              },
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      tr(context,
                          'Athletes enter this code in their Athlete tab. Entering it is their approval: you then see their program, logs, readiness, body entries and meets, and you can comment and send programs. Either of you can remove the link at any time.'),
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (cloud.coachLoading && cloud.athletes.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (cloud.athletes.isEmpty)
                  const Panel(child: T('No athletes yet. Share your code; athletes appear here as soon as they enter it.'))
                else
                  for (final l in cloud.athletes) ...[_AthleteTile(link: l), const SizedBox(height: 8)],
                const SizedBox(height: 8),
                Text(
                  tr(context,
                      'To send a program, build it in your own Program tab first (start one from a template or Build your own and edit it), then open the athlete and tap Send a program. Percentages use the athlete\'s own maxes.'),
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AthleteTile extends StatelessWidget {
  final CoachLink link;
  const _AthleteTile({required this.link});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final p = Palette.of(context);
    final unread = cloud.unreadFor(athleteId: link.athleteId);
    final waiting = cloud.sent.where((a) => a.athleteId == link.athleteId && a.status == 'sent').length;
    final name = _athleteName(context, link);
    final facts = [
      tr(context, link.athleteSex == 'female' ? 'Women' : 'Men'),
      tr(context, link.athleteDivision == 'equipped' ? 'Equipped' : 'Classic'),
      if (link.athleteClass.isNotEmpty) '${link.athleteClass} kg',
    ].join(' · ');
    final synced = link.athleteSyncedAt == null
        ? tr(context, 'Not synced yet')
        : tr(context, 'Synced {t}', {'t': timeAgo(link.athleteSyncedAt!)});
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoachAthleteScreen(link: link))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: p.navy,
              child: Text(name.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('$facts · $synced', style: TextStyle(color: p.muted, fontSize: 12.5)),
                if (waiting > 0)
                  Text(tr(context, 'Programs waiting for an answer: {n}', {'n': waiting}),
                      style: TextStyle(color: p.blue, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (unread > 0)
              Badge(
                label: Text('$unread'),
                backgroundColor: p.red,
                child: Icon(Icons.chat_bubble_outline, color: p.muted),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: p.muted),
          ]),
        ),
      ),
    );
  }
}

// ======================================================================
// One athlete
// ======================================================================

class CoachAthleteScreen extends StatefulWidget {
  final CoachLink link;
  const CoachAthleteScreen({super.key, required this.link});

  @override
  State<CoachAthleteScreen> createState() => _CoachAthleteScreenState();
}

class _CoachAthleteScreenState extends State<CoachAthleteScreen> {
  AppStore? viewer;
  DateTime? syncedAt;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final cloud = CloudScope.read(context);
    try {
      final snap = await cloud.athleteSnapshot(widget.link.athleteId);
      if (!mounted) return;
      final old = viewer;
      setState(() {
        viewer = snap == null ? null : AppStore.viewer(snap.data, ownerId: widget.link.athleteId);
        syncedAt = snap?.syncedAt;
        loading = false;
      });
      // Dispose the old copy after this frame, once nothing listens to it any more.
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      await cloud.refreshCoach();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not reach the server. Check your internet connection.';
      });
    }
  }

  @override
  void dispose() {
    viewer?.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    final cloud = CloudScope.read(context);
    final name = _athleteName(context, widget.link);
    final ok = await confirmDialog(context,
        title: tr(context, 'Remove {name}?', {'name': name}),
        body: 'You will no longer see their data. Comments stay with the athlete. They can connect again with your code.',
        action: 'Remove',
        danger: true);
    if (!ok) return;
    final err = await cloud.removeLink(widget.link.id);
    if (!mounted) return;
    if (err != null) {
      toast(context, err);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = StoreScope.read(context);
    final name = _athleteName(context, widget.link);
    final v = viewer;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: loading ? null : _load),
            PopupMenuButton<String>(
              onSelected: (s) {
                if (s == 'send') showSendProgramSheet(context, own, widget.link);
                if (s == 'remove') _remove();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'send', child: T('Send a program')),
                PopupMenuItem(value: 'remove', child: T('Remove athlete')),
              ],
            ),
          ],
          bottom: v == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: tr(context, 'Overview')),
                    Tab(text: tr(context, 'Program')),
                    Tab(text: tr(context, 'Progress')),
                    Tab(text: tr(context, 'Body')),
                  ],
                ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : (v == null
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    Panel(
                      child: T(error ??
                          'This athlete has not synced yet. Their data appears after they open the app while signed in.'),
                    ),
                  ])
                : StoreScope(
                    store: v,
                    child: TabBarView(children: [
                      _CoachOverview(link: widget.link, syncedAt: syncedAt, own: own),
                      const _CoachProgramTab(),
                      const ProgressScreen(),
                      const BodyScreen(),
                    ]),
                  )),
      ),
    );
  }
}

class _CoachOverview extends StatelessWidget {
  final CoachLink link;
  final DateTime? syncedAt;
  final AppStore own;
  const _CoachOverview({required this.link, required this.syncedAt, required this.own});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cloud = CloudScope.of(context);
    final p = Palette.of(context);
    final pr = store.profile;
    final prog = store.active;
    final bw = store.latestWeight;

    // Best estimated max per lift, falling back to the entered max.
    final best = {for (final l in kLifts) l: store.bestOverall(l) ?? pr.maxes[l] ?? 0.0};
    final total = best.values.fold<double>(0, (a, b) => a + b);
    final gl = store.gl(total, bw);

    // Readiness over the last 7 days.
    final weekAgo = addDays(todayIso(), -7);
    final scores = [
      for (final w in prog?.workouts ?? const <Workout>[])
        if (w.readiness != null && w.date.compareTo(weekAgo) >= 0 && w.date.compareTo(todayIso()) <= 0) w.readiness!.score
    ];
    final readiness = scores.isEmpty ? null : (scores.reduce((a, b) => a + b) / scores.length).round();

    final done = prog?.workouts.where((w) => w.completed).length ?? 0;
    final missed = prog?.workouts.where((w) => store.statusOf(w) == 'missed').length ?? 0;
    final meet = store.currentMeet;
    final sent = cloud.sent.where((a) => a.athleteId == link.athleteId).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          syncedAt == null ? tr(context, 'Not synced yet') : tr(context, 'Data from {t}', {'t': timeAgo(syncedAt!)}),
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('AT A GLANCE', style: eyebrowStyle(context)),
            const SizedBox(height: 10),
            Wrap(spacing: 22, runSpacing: 12, children: [
              StatTile(label: 'Est. total', value: fmt(total), unit: 'kg'),
              if (gl != null) StatTile(label: 'GL points', value: fmt1(gl)),
              if (bw != null) StatTile(label: 'Bodyweight', value: fmt1(bw), unit: 'kg'),
              if (readiness != null) StatTile(label: 'Readiness (7 days)', value: '$readiness', unit: '/100'),
            ]),
            const SizedBox(height: 12),
            for (final l in kLifts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 92, child: Align(alignment: AlignmentDirectional.centerStart, child: LiftTag(l))),
                  Expanded(
                    child: Text(
                      tr(context, 'Max {m} kg · best e1RM {e}', {
                        'm': fmt(pr.maxes[l] ?? 0),
                        'e': store.bestOverall(l) == null ? '—' : '${fmt(r25(store.bestOverall(l)!))} kg',
                      }),
                      style: const TextStyle(fontSize: 13, fontFeatures: kTabular),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('CURRENT PROGRAM', style: eyebrowStyle(context)),
            const SizedBox(height: 6),
            if (prog == null)
              const T('No program yet.')
            else ...[
              Text(prog.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                tr(context, 'Week {w} of {n} · {d}/{t} workouts done · {m} not logged', {
                  'w': store.currentWeekOf(prog),
                  'n': prog.weeks,
                  'd': done,
                  't': prog.workouts.length,
                  'm': missed,
                }),
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ],
            if (meet != null) ...[
              const SizedBox(height: 12),
              T('NEXT MEET', style: eyebrowStyle(context)),
              const SizedBox(height: 4),
              Text('${meet.name} · ${weekdayDate(meet.date)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((store.daysToMeet(meet) ?? -1) >= 0)
                Text(tr(context, '{n} days to go', {'n': store.daysToMeet(meet)}),
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            T('PROGRAMS YOU SENT', style: eyebrowStyle(context)),
            const SizedBox(height: 6),
            if (sent.isEmpty) T('None yet.', style: TextStyle(color: p.muted)),
            for (final a in sent)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.programName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        tr(context, '{n} weeks from {d}', {'n': a.weeks, 'd': a.start.isEmpty ? '—' : shortDate(a.start)}),
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                    ]),
                  ),
                  _AssignmentStatus(a.status),
                  if (a.status == 'sent')
                    IconButton(
                      tooltip: 'Take back',
                      icon: const Icon(Icons.undo),
                      onPressed: () async {
                        final err = await cloud.withdrawProgram(a.id);
                        if (context.mounted) toast(context, err ?? 'Program taken back.');
                      },
                    ),
                ]),
              ),
            const SizedBox(height: 4),
            FilledButton.icon(
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const T('Send a program'),
              onPressed: () => showSendProgramSheet(context, own, link),
            ),
          ]),
        ),
      ],
    );
  }
}

class _AssignmentStatus extends StatelessWidget {
  final String status;
  const _AssignmentStatus(this.status);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (label, color) = switch (status) {
      'accepted' => ('Accepted', p.ok),
      'declined' => ('Declined', p.red),
      _ => ('Waiting', p.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(20)),
      child: Text(tr(context, label), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// The athlete's active program: week strip and workout cards (tap for logs and comments).
class _CoachProgramTab extends StatelessWidget {
  const _CoachProgramTab();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final prog = store.active;
    if (prog == null) {
      return ListView(padding: const EdgeInsets.all(16), children: const [Panel(child: T('No program yet.'))]);
    }
    final w = store.week.clamp(1, prog.weeks).toInt();
    final (a, b) = store.weekRange(w);
    final list = store.workoutsInWeek(w);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            eyebrow: '${tr(context, prog.level.toUpperCase())} · ${tr(context, '{n} WEEKS', {'n': prog.weeks})}',
            title: prog.name.toUpperCase(),
            bottom: const WeekStrip(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('${tr(context, 'WEEK {n}', {'n': w})} · ${shortDate(a)} – ${shortDate(b)}',
                style: headingStyle(context, size: 18)),
          ),
          if (prog.adjustments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in prog.adjustments)
                  Chip(
                    avatar: Icon(x.kg > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16, color: x.kg > 0 ? p.ok : p.warn),
                    label: Text('${tr(context, kLiftNames[x.lift] ?? x.lift)} ${x.kg > 0 ? '+' : '−'}${fmt(x.kg.abs())} kg · W${x.fromWeek}'),
                  ),
              ]),
            ),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 6), child: Panel(child: T('No workouts this week.'))),
          for (final x in list)
            Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: WorkoutCard(workout: x)),
        ],
      ),
    );
  }
}

// ======================================================================
// Read-only workout with comments (coach side)
// ======================================================================

class CoachWorkoutScreen extends StatelessWidget {
  final String workoutId;
  const CoachWorkoutScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final w = store.workout(workoutId);
    if (w == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: T('This workout was deleted.')));
    }
    final maxes = store.maxesFor(w);
    final dur = store.durationOf(w);
    final bw = w.bodyweight ?? store.body[w.date]?.weight;
    final r = w.readiness;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, w.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(children: [
            Expanded(child: Text(weekdayDate(w.date), style: headingStyle(context, size: 18))),
            StatusChip(store.statusOf(w)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 22, runSpacing: 10, children: [
            if (dur != null) StatTile(label: 'Duration', value: fmtDuration(dur)),
            if (bw != null) StatTile(label: 'Bodyweight', value: fmt1(bw), unit: 'kg'),
            if (r != null) StatTile(label: 'Readiness', value: '${r.score}', unit: '/100'),
            if (w.loadScale != 1.0) StatTile(label: 'Today\'s load', value: '${(w.loadScale * 100).round()}', unit: '%'),
          ]),
          if (r != null) ...[
            const SizedBox(height: 6),
            Text(
              tr(context, 'Sleep {s} h · energy {e}/5 · soreness {so}/5 · stress {st}/5',
                  {'s': fmt1(r.sleepHours), 'e': r.energy, 'so': r.soreness, 'st': r.stress}),
              style: TextStyle(color: p.muted, fontSize: 12.5),
            ),
          ],
          if (w.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            T('ATHLETE NOTES', style: eyebrowStyle(context)),
            const SizedBox(height: 4),
            NoteBox(w.notes.trim()),
          ],
          const SizedBox(height: 12),
          for (final e in w.exercises) ...[
            _ExerciseReadOnly(slot: e, maxes: maxes),
            const SizedBox(height: 10),
          ],
          if (w.exercises.isEmpty) const Panel(child: T('No exercises in this workout.')),
          const SizedBox(height: 8),
          if (store.ownerId != null && store.activeId != null)
            CommentThread(athleteId: store.ownerId!, programId: store.activeId!, workoutId: w.id),
        ],
      ),
    );
  }
}

class _ExerciseReadOnly extends StatelessWidget {
  final ExerciseSlot slot;
  final Map<String, double> maxes;
  const _ExerciseReadOnly({required this.slot, required this.maxes});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = <({int i, LoggedSet x})>[
      for (var i = 0; i < slot.log.length; i++)
        if (!slot.log[i].isEmpty) (i: i, x: slot.log[i])
    ];
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (slot.lift != null) ...[LiftTag(slot.lift!), const SizedBox(width: 8)],
          Expanded(child: Text(tr(context, slot.name), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        const SizedBox(height: 4),
        Text('${tr(context, 'Plan')}: ${slot.summary(maxes)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        if (rows.isEmpty) T('Not logged.', style: TextStyle(color: p.muted, fontSize: 13)),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${r.i + 1}', style: TextStyle(color: p.muted, fontFeatures: kTabular))),
              Icon(
                r.x.status == 1 ? Icons.check_circle : (r.x.status == 2 ? Icons.cancel : Icons.radio_button_unchecked),
                size: 18,
                color: r.x.status == 1 ? p.ok : (r.x.status == 2 ? p.red : p.line),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (r.x.w.trim().isNotEmpty) '${r.x.w.trim()} kg',
                    if (r.x.r.trim().isNotEmpty) '× ${r.x.r.trim()}',
                    if (r.x.rpe.trim().isNotEmpty) '@ RPE ${r.x.rpe.trim()}',
                  ].join(' '),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: kTabular),
                ),
              ),
              if (slot.lift != null && r.x.status != 2 && estimatedMax(r.x.w, r.x.r, r.x.rpe) != null)
                Text('e1RM ${fmt(r25(estimatedMax(r.x.w, r.x.r, r.x.rpe)!))}',
                    style: TextStyle(color: p.muted, fontSize: 12, fontFeatures: kTabular)),
            ]),
          ),
      ]),
    );
  }
}

// ======================================================================
// Comments (used by both coach and athlete)
// ======================================================================

class CommentThread extends StatefulWidget {
  final String athleteId;
  final String programId;
  final String workoutId;
  const CommentThread({super.key, required this.athleteId, required this.programId, required this.workoutId});

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final ctl = TextEditingController();
  List<CoachComment> items = [];
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(CommentThread old) {
    super.didUpdateWidget(old);
    if (old.workoutId != widget.workoutId || old.programId != widget.programId) _load();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cloud = CloudScope.read(context);
    try {
      final list = await cloud.comments(widget.athleteId, widget.programId, widget.workoutId);
      if (!mounted) return;
      setState(() {
        items = list;
        loading = false;
        error = null;
      });
      await cloud.markRead(widget.athleteId, widget.programId, widget.workoutId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Comments could not be loaded. Check your internet connection.';
      });
    }
  }

  Future<void> _send() async {
    if (sending) return;
    setState(() => sending = true);
    final cloud = CloudScope.read(context);
    final err = await cloud.addComment(widget.athleteId, widget.programId, widget.workoutId, ctl.text);
    if (!mounted) return;
    setState(() => sending = false);
    if (err != null) {
      toast(context, err);
      return;
    }
    ctl.clear();
    FocusScope.of(context).unfocus();
    await _load();
  }

  Future<void> _delete(CoachComment c) async {
    final ok = await confirmDialog(context, title: 'Delete this comment?', body: c.body, action: 'Delete', danger: true);
    if (!ok || !mounted) return;
    final err = await CloudScope.read(context).deleteComment(c.id);
    if (!mounted) return;
    if (err != null) toast(context, err);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final p = Palette.of(context);
    final me = cloud.myId;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.forum_outlined, size: 18, color: p.muted),
          const SizedBox(width: 6),
          T('COACH COMMENTS', style: eyebrowStyle(context)),
        ]),
        const SizedBox(height: 8),
        if (loading)
          const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (error != null)
          Text(tr(context, error!), style: TextStyle(color: p.warn, fontSize: 12.5))
        else if (items.isEmpty)
          T('No comments yet.', style: TextStyle(color: p.muted, fontSize: 13)),
        for (final c in items) _bubble(context, p, c, mine: c.authorId == me),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: ctl,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: tr(context, me == widget.athleteId ? 'Reply to your coach' : 'Comment on this workout'),
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            icon: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send, color: p.red),
            onPressed: sending ? null : _send,
          ),
        ]),
      ]),
    );
  }

  Widget _bubble(BuildContext context, Palette p, CoachComment c, {required bool mine}) {
    final who = mine ? tr(context, 'You') : (c.authorId == widget.athleteId ? tr(context, 'Athlete') : tr(context, 'Coach'));
    final when = '${shortDate(isoDate(c.createdAt))} ${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: mine ? () => _delete(c) : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: BoxDecoration(
            color: mine ? p.navy : p.sunk,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$who · $when',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mine ? p.navyMuted : p.muted)),
            const SizedBox(height: 2),
            Text(c.body, style: TextStyle(fontSize: 14, color: mine ? p.onNavy : p.ink)),
          ]),
        ),
      ),
    );
  }
}

// ======================================================================
// Send a program
// ======================================================================

String _nextMonday() {
  final now = DateTime.now();
  final add = (DateTime.monday - now.weekday + 7) % 7;
  return isoDate(now.add(Duration(days: add == 0 ? 7 : add)));
}

Future<void> showSendProgramSheet(BuildContext context, AppStore own, CoachLink link) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SendProgramSheet(own: own, link: link),
    );

class _SendProgramSheet extends StatefulWidget {
  final AppStore own;
  final CoachLink link;
  const _SendProgramSheet({required this.own, required this.link});

  @override
  State<_SendProgramSheet> createState() => _SendProgramSheetState();
}

class _SendProgramSheetState extends State<_SendProgramSheet> {
  String? programId;
  String start = _nextMonday();
  final note = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    programId = widget.own.activeId ?? (widget.own.programs.isEmpty ? null : widget.own.programs.last.id);
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    Program? src;
    for (final x in widget.own.programs) {
      if (x.id == programId) src = x;
    }
    if (src == null) return;
    setState(() => sending = true);
    final cloud = CloudScope.read(context);
    final err = await cloud.sendProgram(widget.link.athleteId, AppStore.planOnly(src, start), note.text);
    if (!mounted) return;
    setState(() => sending = false);
    if (err != null) {
      toast(context, err);
      return;
    }
    toast(context, tr(context, 'Sent to {name}. They will see it in their Athlete tab.', {'name': _athleteName(context, widget.link)}));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final programs = widget.own.programs.reversed.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(tr(context, 'Send a program to {name}', {'name': _athleteName(context, widget.link)}),
              style: headingStyle(context, size: 20)),
          const SizedBox(height: 6),
          Text(
            tr(context,
                'Only the plan is sent: exercises, sets, percentages, reps and RPE targets. Your own logs stay on your phone. Percentages use the athlete\'s maxes.'),
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (programs.isEmpty)
            const Panel(child: T('You have no programs yet. Build one in your Program tab first.'))
          else
            Column(children: [
                for (final x in programs)
                  RadioListTile<String>(
                    value: x.id,
                    groupValue: programId,
                    onChanged: (v) => setState(() => programId = v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(tr(context, '{lvl} · {n} weeks · {w} workouts',
                        {'lvl': tr(context, x.level), 'n': x.weeks, 'w': x.workouts.length})),
                  ),
              ]),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const T('Starts on'),
            subtitle: Text(weekdayDate(start)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await pickIsoDate(context, start, help: tr(context, 'Day 1 of the program'));
              if (d != null) setState(() => start = d);
            },
          ),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr(context, 'Note to the athlete (optional)'), counterText: ''),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined, size: 18),
            label: const T('Send program'),
            onPressed: (sending || programId == null) ? null : _send,
          ),
        ]),
      ),
    );
  }
}

// ======================================================================
// Athlete side: the Coach panel in the Athlete tab
// ======================================================================

class CoachPanel extends StatelessWidget {
  const CoachPanel({super.key});

  Future<void> _connect(BuildContext context) async {
    final cloud = CloudScope.read(context);
    final code = await promptText(context, title: 'Connect to a coach', label: 'Coach code (6 characters)', action: 'Connect');
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final err = await cloud.connectCoach(code);
    if (!context.mounted) return;
    toast(context, err ?? 'Connected. Your coach can now see your training.');
  }

  Future<void> _toggleCoaching(BuildContext context, bool on) async {
    final cloud = CloudScope.read(context);
    if (!on) {
      final ok = await confirmDialog(context,
          title: 'Turn off coach mode?',
          body: 'The Coach tab is hidden. Your athletes stay linked, and your code stays the same if you turn it back on.',
          action: 'Turn off');
      if (!ok) return;
    }
    final err = on ? await cloud.enableCoaching() : await cloud.disableCoaching();
    if (!context.mounted) return;
    if (err != null) {
      toast(context, err);
    } else if (on) {
      toast(context, 'Coach mode is on. Open the Coach tab to share your code.');
    }
  }

  Future<void> _answer(BuildContext context, ProgramAssignment a, bool accept) async {
    final cloud = CloudScope.read(context);
    if (accept) {
      final ok = await confirmDialog(context,
          title: tr(context, 'Start {name}?', {'name': a.programName}),
          body: 'It becomes your active program. Your current program and its logs are kept; you can switch back under Programs.',
          action: 'Start program');
      if (!ok || !context.mounted) return;
    }
    final err = await cloud.answerProgram(a, accept: accept);
    if (!context.mounted) return;
    toast(context, err ?? (accept ? 'Program added and made active.' : 'Program declined.'));
  }

  Future<void> _removeCoach(BuildContext context, CoachLink l) async {
    final cloud = CloudScope.read(context);
    final ok = await confirmDialog(context,
        title: tr(context, 'Remove {name} as your coach?', {'name': _coachName(context, cloud, l.coachId)}),
        body: 'They will no longer see your data. You can connect again later with their code.',
        action: 'Remove',
        danger: true);
    if (!ok || !context.mounted) return;
    final err = await cloud.removeLink(l.id);
    if (context.mounted && err != null) toast(context, err);
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    final p = Palette.of(context);
    if (!cloud.signedIn) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('COACH', style: headingStyle(context, size: 18)),
          const SizedBox(height: 6),
          T('Sign in to connect with a coach, or to coach other lifters.', style: TextStyle(color: p.muted)),
        ]),
      );
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: T('COACH', style: headingStyle(context, size: 18))),
          if (cloud.coachLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),

        // Programs waiting for an answer.
        for (final a in cloud.inbox)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.blue.withAlpha(20),
              border: Border.all(color: p.blue.withAlpha(140)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr(context, '{coach} sent you a program', {'coach': _coachName(context, cloud, a.coachId)}),
                  style: eyebrowStyle(context, color: p.blue)),
              const SizedBox(height: 4),
              Text(a.programName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(tr(context, '{n} weeks from {d}', {'n': a.weeks, 'd': a.start.isEmpty ? '—' : shortDate(a.start)}),
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              if (a.note.trim().isNotEmpty) ...[const SizedBox(height: 6), NoteBox(a.note.trim())],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _answer(context, a, false), child: const T('Decline')),
                ),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(onPressed: () => _answer(context, a, true), child: const T('Accept'))),
              ]),
            ]),
          ),

        // My coaches.
        for (final l in cloud.coaches)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: p.navy, child: const Icon(Icons.sports, size: 18, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_coachName(context, cloud, l.coachId), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    tr(context, 'Can see your training · unread comments: {n}', {'n': cloud.unreadFromCoach}),
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ]),
              ),
              IconButton(tooltip: 'Remove coach', icon: const Icon(Icons.link_off), onPressed: () => _removeCoach(context, l)),
            ]),
          ),
        if (cloud.coaches.isEmpty)
          T('Have a coach? Ask for their 6-character code and connect. They will see your program, logs, readiness, body entries and meets, comment on workouts and send you programs.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.link, size: 18),
          label: const T('Connect to a coach'),
          onPressed: () => _connect(context),
        ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const T('I coach other lifters'),
          subtitle: T(cloud.isCoach ? 'The Coach tab is on.' : 'Adds a Coach tab with your code and your athletes.'),
          value: cloud.isCoach,
          onChanged: (v) => _toggleCoaching(context, v),
        ),
      ]),
    );
  }
}
