// Meet tab: plan a competition, line the program up with it, pick attempts,
// plan the weigh-in, pack the bag, and run meet day with three referee lights.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'workout_screen.dart';
import '../../l10n/l10n.dart';
import '../motion.dart';

const _ordinals = ['1st', '2nd', '3rd'];

const kChecklist = [
  'Federation membership card and photo ID',
  'Meet registration confirmation',
  'Singlet (federation-approved)',
  'Plain crew-neck T-shirt',
  'Knee-high socks for deadlift',
  'Squat and bench shoes',
  'Deadlift shoes or slippers',
  'Belt (10 cm wide max, approved list)',
  'Knee sleeves (approved list)',
  'Wrist wraps (1 m max)',
  'Briefs (non-supportive)',
  'Chalk and a towel',
  'Food and drinks for the whole day',
  'Warm clothes for the warm-up room',
  'Attempt card numbers written down',
];

String? _standingLine(AppStore store, String metric, double? value) {
  if (value == null) return null;
  final cls = store.standingFor(metric, value, weightClass: store.profile.weightClass);
  final all = store.standingFor(metric, value);
  final s = cls ?? all;
  if (s == null) return null;
  final top = (100 - s.pct).clamp(0.5, 100.0).toDouble();
  return 'Top ${top < 10 ? fmt1(top) : top.round()}% of ${store.profile.equipped ? 'equipped' : 'classic'} ${s.label} '
      '(${fmtInt(s.n)} lifters)';
}

/// A second score next to the lifter's own: GL when they use another formula, else DOTS.
(String, double?) _otherScore(AppStore store, double? total, double? bw) {
  final f = store.profile.scoreFormula == 'gl' ? 'dots' : 'gl';
  final v = (total == null || bw == null)
      ? null
      : scorePoints(f, total, bw, female: store.profile.female, equipped: store.profile.equipped);
  return (kScoreNames[f]!, v);
}

class MeetScreen extends StatelessWidget {
  const MeetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final m = store.currentMeet;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ScreenHeader(
          eyebrow: m == null ? 'COMPETITION' : '${m.federation} · ${weekdayDate(m.date).toUpperCase()}',
          title: m == null ? 'MEET' : m.name.toUpperCase(),
          actions: [
            if (m != null)
              IconButton(
                tooltip: 'Edit meet',
                icon: Icon(Icons.edit_outlined, color: p.onNavy),
                onPressed: () => editMeetDialog(context, m),
              ),
            IconButton(
              tooltip: 'Plan another meet',
              icon: Icon(Icons.add, color: p.onNavy),
              onPressed: () => editMeetDialog(context, null),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: m == null
              ? Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    T('NO MEET PLANNED', style: headingStyle(context, size: 18)),
                    const SizedBox(height: 6),
                    const T('Add your meet date to line up your peak, choose attempts, '
                        'plan your weigh-in and run meet day with referee lights.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => editMeetDialog(context, null), child: const T('Plan a meet')),
                  ]),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Countdown(meet: m),
                  const SizedBox(height: 12),
                  _AlignPanel(meet: m),
                  const SizedBox(height: 12),
                  _AttemptsPanel(meet: m),
                  const SizedBox(height: 12),
                  _WeighInPanel(meet: m),
                  const SizedBox(height: 12),
                  _ChecklistPanel(meet: m),
                  if (store.meets.length > 1) ...[
                    const SizedBox(height: 12),
                    _OtherMeets(current: m),
                  ],
                ]),
        ),
      ],
    );
  }
}

Future<void> editMeetDialog(BuildContext context, Meet? m) async {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: m?.name ?? '');
  final place = TextEditingController(text: m?.location ?? '');
  var date = m?.date ?? addDays(todayIso(), 70);
  var weighIn = m?.weighIn ?? '2h';
  final result = await showAppDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(m == null ? 'Plan a meet' : 'Edit meet'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: name,
              autofocus: m == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(label: T('Meet name'), hintText: 'e.g. Bahrain Classic Open'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: place,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(label: T('Place (optional)')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(weekdayDate(date)),
              onPressed: () async {
                final d = await pickIsoDate(ctx, date, help: 'Meet day');
                if (d != null) setS(() => date = d);
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '2h', label: T('2-hour weigh-in')),
                ButtonSegment(value: '24h', label: T('24-hour')),
              ],
              selected: {weighIn},
              onSelectionChanged: (s) => setS(() => weighIn = s.first),
            ),
            const SizedBox(height: 4),
            T('IPF meets use a 2-hour weigh-in.', style: TextStyle(color: Palette.of(ctx).muted, fontSize: 12)),
          ]),
        ),
        actions: [
          if (m != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: T('Delete', style: TextStyle(color: Palette.of(ctx).red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const T('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const T('Save')),
        ],
      ),
    ),
  );
  if (result == 'delete' && m != null) {
    if (!context.mounted) return;
    final ok = await confirmDialog(context,
        title: 'Delete ${m.name}?', body: 'Its attempts, results and checklist are deleted.', action: 'Delete', danger: true);
    if (ok) store.deleteMeet(m.id);
    return;
  }
  if (result != 'save') return;
  final title = name.text.trim().isEmpty ? 'My meet' : name.text.trim();
  if (m == null) {
    final nm = store.addMeet(title, date, weighIn);
    store.updateMeet(nm, (x) => x.location = place.text.trim());
    store.fillSuggestedAttempts(nm);
  } else {
    store.updateMeet(m, (x) {
      x.name = title;
      x.date = date;
      x.weighIn = weighIn;
      x.location = place.text.trim();
    }, bump: true);
  }
}

class _Countdown extends StatelessWidget {
  final Meet meet;
  const _Countdown({required this.meet});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final days = store.daysToMeet(meet) ?? 0;
    final weeks = days ~/ 7;
    final big = days < 0 ? tr(context, 'DONE') : (days == 0 ? tr(context, 'TODAY') : '$days');
    final sub = days < 0
        ? tr(context, 'This meet was {n} days ago.', {'n': -days})
        : (days == 0
            ? tr(context, 'Meet day. Good luck.')
            : (weeks > 0 ? tr(context, 'days to go · about {n} weeks', {'n': weeks}) : tr(context, 'days to go')));
    final total = meet.total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(big, style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, height: 1, color: p.onNavy, fontFeatures: kTabular)),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(sub, style: TextStyle(color: p.navyMuted, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        if (meet.location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meet.location, style: TextStyle(color: p.navyMuted, fontSize: 13)),
        ],
        if (meet.started) ...[
          const SizedBox(height: 8),
          Text(total == null ? tr(context, 'Meet in progress') : tr(context, 'Meet total {n} kg', {'n': fmt(total)}),
              style: TextStyle(color: p.onNavy, fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: p.red, foregroundColor: Colors.white),
          icon: const Icon(Icons.flag, size: 18),
          label: Text(meet.started ? 'Open meet day' : 'Start meet day'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeetDayScreen(meetId: meet.id))),
        ),
      ]),
    );
  }
}

class _AlignPanel extends StatelessWidget {
  final Meet meet;
  const _AlignPanel({required this.meet});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final prog = store.active;
    final a = store.alignment(meet);
    final lined = a.programMeetDate != null && a.deltaDays == 0;
    String text;
    if (prog == null || a.programMeetDate == null) {
      text = 'Start a program to line up your peak with this meet.';
    } else if (lined) {
      text = tr(context, '{p} peaks on meet day, {d}.', {'p': tr(context, prog.name), 'd': weekdayDate(meet.date)});
    } else {
      final d = a.deltaDays.abs();
      text = tr(context, a.deltaDays > 0 ? '{p} reaches its meet day on {d}, {n} days before your meet.' : '{p} reaches its meet day on {d}, {n} days after your meet.',
          {'p': tr(context, prog.name), 'd': weekdayDate(a.programMeetDate!), 'n': d});
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(lined ? Icons.check_circle : Icons.event_note, color: lined ? p.ok : p.blue, size: 20),
          const SizedBox(width: 8),
          T('PEAK TIMING', style: eyebrowStyle(context)),
        ]),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (!lined && a.programMeetDate != null) ...[
          const SizedBox(height: 4),
          Text(
            a.anyLogged
                ? 'Lining up moves every workout you haven\'t logged by ${a.deltaDays.abs()} days. Logged workouts keep their dates.'
                : 'Lining up moves the whole program by ${a.deltaDays.abs()} days.',
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              store.alignProgramToMeet(meet);
              toast(context, 'Program lined up with ${meet.name}.');
            },
            child: const T('Line up my program'),
          ),
        ],
      ]),
    );
  }
}

class _AttemptsPanel extends StatelessWidget {
  final Meet meet;
  const _AttemptsPanel({required this.meet});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final bw = meet.weighInKg ?? store.profile.bwTarget[1];
    final third = meet.plannedTotal(2), opener = meet.plannedTotal(0);
    final gl = third == null ? null : store.gl(third, bw);
    final pts = third == null ? null : store.points(third, bw);
    final other = _otherScore(store, third, bw);
    final standing = _standingLine(store, 'gl', gl);
    final k = 'att-${meet.id}-${store.revision}';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: T('ATTEMPTS', style: headingStyle(context, size: 18))),
          TextButton(
            onPressed: () {
              store.fillSuggestedAttempts(meet);
              toast(context, 'Attempts set from your recent training.');
            },
            child: const T('Suggest'),
          ),
        ]),
        T('Opener about 91% of your projected max, 2nd about 96.5%, 3rd about 101%. '
            'Open with a weight you could lift on your worst day.',
            style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        for (final l in kLifts) ...[
          Builder(builder: (context) {
            final s = store.suggestAttempts(l);
            final trend = store.predict(l, meet.date);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LiftTag(l),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr(context, 'Projected {n} kg', {'n': fmt(r25(s.projected))}) + ' · ${s.basis}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
                ),
              ]),
              if (trend != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    tr(context, 'Trend on meet day: {kg} kg (likely {lo}–{hi})', {
                      'kg': fmt(r25(trend.kg)),
                      'lo': fmt(r25(trend.low)),
                      'hi': fmt(r25(trend.high)),
                    }),
                    style: TextStyle(fontSize: 12, color: p.blue, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('$k-$l-$i'),
                      initialValue: meet.attempts[l]![i].kg,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: kTabular),
                      decoration: InputDecoration(labelText: tr(context, _ordinals[i]), hintText: fmt(s.attempts[i]), suffixText: 'kg'),
                      onChanged: (v) => store.setAttemptKg(meet, l, i, v),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
            ]);
          }),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: StatTile(label: 'Opener total', value: opener == null ? '—' : fmt(opener), unit: 'kg')),
              Expanded(child: StatTile(label: 'Planned total', value: third == null ? '—' : fmt(third), unit: 'kg')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(label: store.pointsName, value: pts == null ? '—' : pts.toStringAsFixed(1))),
              Expanded(child: StatTile(label: other.$1, value: other.$2 == null ? '—' : other.$2!.toStringAsFixed(1))),
            ]),
            const SizedBox(height: 6),
            Text('At ${fmt(bw)} kg bodyweight${meet.weighInKg == null ? ' (top of your meet range)' : ''}.',
                style: TextStyle(color: p.muted, fontSize: 12)),
            if (standing != null) ...[
              const SizedBox(height: 6),
              Text(standing, style: TextStyle(color: p.blue, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _WeighInPanel extends StatelessWidget {
  final Meet meet;
  const _WeighInPanel({required this.meet});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final pr = store.profile;
    final limit = pr.classLimit;
    final avg = store.bodyTrend().avg7 ?? store.latestWeight;
    final days = store.daysToMeet(meet) ?? 0;
    String status;
    Color color = p.muted;
    if (limit == null) {
      status = 'No upper limit in the ${pr.weightClass} kg class.';
    } else if (avg == null) {
      status = 'Log your bodyweight to see how far you are from −${pr.weightClass} kg.';
    } else {
      final gap = avg - limit;
      final pct = gap / limit * 100;
      if (gap <= 0) {
        status = '${fmt1(-gap)} kg under the −${pr.weightClass} kg limit. You make weight at your current average.';
        color = p.ok;
      } else if (meet.weighIn == '2h' && pct > 2) {
        status = '${fmt1(gap)} kg over (${fmt1(pct)}%). With a 2-hour weigh-in, lose it with food over the coming weeks, '
            'not by cutting water. If that isn\'t realistic by meet day, consider the next class up.';
        color = p.warn;
      } else {
        status = '${fmt1(gap)} kg over (${fmt1(pct)}%). Bring it down gradually; '
            '${days > 0 ? 'you have $days days. ' : ''}Avoid a hard water cut.';
        color = p.blue;
      }
    }
    final k = 'wi-${meet.id}-${store.revision}';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        T('WEIGH-IN', style: headingStyle(context, size: 18)),
        const SizedBox(height: 4),
        Text(
          meet.weighIn == '2h'
              ? '2-hour weigh-in: you lift 2 hours after stepping on the scale, so there is little time to rehydrate.'
              : '24-hour weigh-in: you weigh in the day before and have more time to eat and drink after.',
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: StatTile(label: 'Class', value: limit == null ? pr.weightClass : '−${pr.weightClass}', unit: 'kg')),
          Expanded(child: StatTile(label: '7-day average', value: avg == null ? '—' : fmt1(avg), unit: avg == null ? '' : 'kg')),
        ]),
        const SizedBox(height: 8),
        Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(k),
          initialValue: meet.weighInKg == null ? '' : fmt(meet.weighInKg!),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(label: T('Weigh-in result (on meet day)'), suffixText: 'kg'),
          onChanged: (v) => store.updateMeet(meet, (x) => x.weighInKg = parseNum(v)),
        ),
      ]),
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  final Meet meet;
  const _ChecklistPanel({required this.meet});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final done = kChecklist.where(meet.checklist.contains).length;
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: T('MEET BAG', style: headingStyle(context, size: 18))),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('$done / ${kChecklist.length}', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 2),
          child: T('Check your federation\'s approved equipment list before the meet.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
        ),
        for (final item in kChecklist)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: meet.checklist.contains(item),
            onChanged: (_) => store.toggleChecklist(meet, item),
            title: Text(tr(context, item)),
          ),
      ]),
    );
  }
}

class _OtherMeets extends StatelessWidget {
  final Meet current;
  const _OtherMeets({required this.current});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final others = [...store.meets.where((m) => m.id != current.id)]..sort((a, b) => b.date.compareTo(a.date));
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        T('OTHER MEETS', style: eyebrowStyle(context)),
        for (final m in others)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${weekdayDate(m.date)}${m.total == null ? '' : ' · total ${fmt(m.total!)} kg'}',
                style: TextStyle(color: p.muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeetDayScreen(meetId: m.id))),
          ),
      ]),
    );
  }
}

// ======================================================================
// meet day
// ======================================================================

class MeetDayScreen extends StatefulWidget {
  final String meetId;
  const MeetDayScreen({super.key, required this.meetId});

  @override
  State<MeetDayScreen> createState() => _MeetDayScreenState();
}

class _MeetDayScreenState extends State<MeetDayScreen> {
  /// Countdown to hand in the next attempt (1 minute after a lift is judged).
  final next = ValueNotifier<DateTime?>(null);
  String nextLabel = '';

  @override
  void dispose() {
    next.dispose();
    super.dispose();
  }

  void _judged(Meet m, String lift, int i) {
    final a = m.attempts[lift]![i];
    if (!a.decided) return;
    final li = kLifts.indexOf(lift);
    if (i < 2) {
      nextLabel = tr(context, 'HAND IN {lift} {n}', {'lift': tr(context, kLiftNames[lift]!.toUpperCase()), 'n': tr(context, _ordinals[i + 1]).toUpperCase()});
      next.value = DateTime.now().add(const Duration(seconds: 60));
    } else if (li < 2) {
      next.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    Meet? m;
    for (final x in store.meets) {
      if (x.id == widget.meetId) m = x;
    }
    final meet = m;
    if (meet == null) return Scaffold(appBar: AppBar(), body: const Center(child: T('This meet was deleted.')));
    final bw = meet.weighInKg;
    final total = meet.total;
    final gl = (total == null || bw == null) ? null : store.gl(total, bw);
    final pts = (total == null || bw == null) ? null : store.points(total, bw);
    final other = _otherScore(store, total, bw);
    final bombed = [for (final l in kLifts) if (meet.attempts[l]!.every((a) => a.decided && !a.good)) l];
    final standing = _standingLine(store, 'gl', gl);
    final k = 'md-${meet.id}-${store.revision}';

    return Scaffold(
      appBar: AppBar(title: Text(meet.name)),
      bottomNavigationBar: ValueListenableBuilder<DateTime?>(
        valueListenable: next,
        builder: (_, end, __) => end == null
            ? const SizedBox.shrink()
            : RestBar(
                end: end,
                total: 60,
                title: nextLabel,
                doneTitle: 'TIME',
                doneText: 'Hand it in now',
                onAdjust: (_) {},
                onClose: () => next.value = null,
              ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.navy, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (final l in kLifts)
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kLiftNames[l]!.toUpperCase(), style: eyebrowStyle(context, color: p.navyMuted)),
                        Text(meet.best(l) == null ? '—' : fmt(meet.best(l)!),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 10),
                Container(height: 1, color: Colors.white.withAlpha(30)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      T('TOTAL', style: eyebrowStyle(context, color: p.navyMuted)),
                      Text(total == null ? '—' : '${fmt(total)} kg',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${tr(context, store.pointsName).toUpperCase()} · ${tr(context, other.$1).toUpperCase()}',
                        style: eyebrowStyle(context, color: p.navyMuted)),
                    Text('${pts == null ? '—' : pts.toStringAsFixed(1)} · ${other.$2 == null ? '—' : other.$2!.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: p.onNavy, fontFeatures: kTabular)),
                  ]),
                ]),
                if (bombed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No good ${bombed.map((l) => kLiftNames[l]!.toLowerCase()).join(' or ')}: no total this meet.',
                        style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700)),
                  ),
                if (standing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(standing, style: TextStyle(color: p.navyMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('$k-bw'),
              initialValue: bw == null ? '' : fmt(bw),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(label: T('Weigh-in bodyweight'), suffixText: 'kg'),
              onChanged: (v) => store.updateMeet(meet, (x) => x.weighInKg = parseNum(v)),
            ),
            const SizedBox(height: 4),
            T('Tap each light as the referees show it: white is a good lift, red is no lift. Two whites count.',
                style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 12),
            for (final l in kLifts) ...[
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    LiftTag(l),
                    const Spacer(),
                    Text(meet.best(l) == null ? tr(context, 'No good lift yet') : tr(context, 'Best {n} kg', {'n': fmt(meet.best(l)!)}),
                        style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 10),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _attemptRow(context, store, p, meet, l, i, '$k-$l-$i'),
                    ),
                  if (parseNum(meet.attempts[l]![0].kg) != null)
                    WarmupList(top: parseNum(meet.attempts[l]![0].kg)!),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attemptRow(BuildContext context, AppStore store, Palette p, Meet meet, String lift, int i, String key) {
    final a = meet.attempts[lift]![i];
    final result = a.decided ? (a.good ? 'GOOD' : 'NO LIFT') : '';
    return Row(children: [
      SizedBox(width: 34, child: Text(tr(context, _ordinals[i]), style: const TextStyle(fontWeight: FontWeight.w800))),
      SizedBox(
        width: 92,
        child: TextFormField(
          key: ValueKey(key),
          initialValue: a.kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: kTabular),
          decoration: const InputDecoration(suffixText: 'kg'),
          onChanged: (v) => store.setAttemptKg(meet, lift, i, v),
        ),
      ),
      const SizedBox(width: 4),
      for (var j = 0; j < 3; j++)
        RefLight(
          status: a.lights[j],
          onTap: () {
            store.cycleLight(meet, lift, i, j);
            _judged(meet, lift, i);
          },
        ),
      const SizedBox(width: 4),
      Expanded(
        child: result.isEmpty
            ? PopupMenuButton<int>(
                tooltip: 'Set all three lights',
                icon: Icon(Icons.more_horiz, color: p.muted),
                onSelected: (v) {
                  store.setAllLights(meet, lift, i, v);
                  _judged(meet, lift, i);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: T('Three white lights')),
                  PopupMenuItem(value: 2, child: T('Three red lights')),
                ],
              )
            : InkWell(
                onTap: () => store.setAllLights(meet, lift, i, 0),
                child: Text(result,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: a.good ? p.ok : p.red)),
              ),
      ),
    ]);
  }
}
