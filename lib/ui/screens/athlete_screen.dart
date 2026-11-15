// Athlete tab: profile (sex, division, class, height), maxes and goals,
// programs (start, switch, delete) and backup / restore.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../../core/cloud.dart';
import 'account_screen.dart';
import 'coach_screen.dart';
import 'program_picker.dart';
import 'tools_screen.dart';
import '../../l10n/l10n.dart';

class AthleteScreen extends StatefulWidget {
  const AthleteScreen({super.key});

  @override
  State<AthleteScreen> createState() => _AthleteScreenState();
}

class _AthleteScreenState extends State<AthleteScreen> {
  final c = <String, TextEditingController>{};
  String sex = 'male';
  String division = 'classic';
  String weightClass = '105';
  int loadedRevision = -1;

  TextEditingController _ctl(String k) => c.putIfAbsent(k, () => TextEditingController());

  void _fill(Profile pr) {
    _ctl('name').text = pr.name;
    _ctl('height').text = fmt(pr.heightCm);
    for (final l in kLifts) {
      _ctl('max-$l').text = fmt(pr.maxes[l] ?? 0);
      _ctl('target-$l').text = fmt(pr.goals[l]?[0] ?? 0);
      _ctl('stretch-$l').text = fmt(pr.goals[l]?[1] ?? 0);
    }
    _ctl('bw-lo').text = fmt(pr.bwTarget[0]);
    _ctl('bw-hi').text = fmt(pr.bwTarget[1]);
    sex = pr.sex;
    division = pr.division;
    weightClass = pr.weightClass;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    // Refill the form when data changes from outside (restore, migration), not while typing.
    if (store.revision != loadedRevision && !_dirty) {
      _fill(store.profile);
      loadedRevision = store.revision;
    }
  }

  bool _dirty = false;

  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    super.dispose();
  }

  List<String> get _classes => sex == 'female' ? kWomenClasses : kMenClasses;

  void _save(AppStore store) {
    final maxes = <String, double>{};
    final goals = <String, List<double>>{};
    for (final l in kLifts) {
      final m = parseNum(_ctl('max-$l').text), t = parseNum(_ctl('target-$l').text), s = parseNum(_ctl('stretch-$l').text);
      if (m == null || t == null || s == null || m <= 0) {
        toast(context, 'Fill in every max and goal before saving.');
        return;
      }
      maxes[l] = m;
      goals[l] = [t, s];
    }
    final lo = parseNum(_ctl('bw-lo').text), hi = parseNum(_ctl('bw-hi').text);
    final bw = (lo != null && hi != null) ? [lo < hi ? lo : hi, lo < hi ? hi : lo] : store.profile.bwTarget;
    final h = parseNum(_ctl('height').text) ?? store.profile.heightCm;
    store.saveProfile(Profile(
      name: _ctl('name').text.trim(),
      sex: sex,
      heightCm: h,
      division: division,
      weightClass: _classes.contains(weightClass) ? weightClass : _classes[5],
      maxes: maxes,
      goals: goals,
      bwTarget: bw,
    ));
    _dirty = false;
    loadedRevision = store.revision;
    FocusScope.of(context).unfocus();
    toast(context, 'Saved. Every target weight now uses these maxes.');
  }

  Widget _num(String key, String label, {String? suffix}) => TextField(
        controller: _ctl(key),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _dirty = true,
        decoration: InputDecoration(labelText: tr(context, label), suffixText: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final pr = store.profile;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ScreenHeader(eyebrow: 'PROFILE · MAXES · PROGRAMS', title: pr.name.isEmpty ? 'ATHLETE' : pr.name.toUpperCase()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _account(context, p),
                const SizedBox(height: 12),
                const CoachPanel(),
                const SizedBox(height: 12),
                _language(context, store),
                const SizedBox(height: 12),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('ATHLETE', style: headingStyle(context, size: 18)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ctl('name'),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => _dirty = true,
                        decoration: const InputDecoration(label: T('Name')),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'male', label: T('Men')),
                          ButtonSegment(value: 'female', label: T('Women')),
                        ],
                        selected: {sex},
                        onSelectionChanged: (s) => setState(() {
                          sex = s.first;
                          _dirty = true;
                          if (!_classes.contains(weightClass)) weightClass = _classes[5];
                        }),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'classic', label: T('Classic (raw)')),
                          ButtonSegment(value: 'equipped', label: T('Equipped')),
                        ],
                        selected: {division},
                        onSelectionChanged: (s) => setState(() {
                          division = s.first;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _classes.contains(weightClass) ? weightClass : _classes[5],
                            decoration: const InputDecoration(label: T('Weight class')),
                            items: [
                              for (final k in _classes)
                                DropdownMenuItem(value: k, child: Text(k.endsWith('+') ? '$k kg' : '−$k kg')),
                            ],
                            onChanged: (v) => setState(() {
                              weightClass = v ?? weightClass;
                              _dirty = true;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _num('height', 'Height', suffix: 'cm')),
                      ]),
                      const SizedBox(height: 4),
                      T('IPF open classes. Used for GL points and the Body tab.',
                          style: TextStyle(color: p.muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('MAXES & GOALS', style: headingStyle(context, size: 18)),
                      const SizedBox(height: 4),
                      T('Every percentage in your program uses these maxes. Update them after a test or a meet.',
                          style: TextStyle(color: p.muted, fontSize: 12.5)),
                      const SizedBox(height: 12),
                      for (final l in kLifts) ...[
                        Row(children: [LiftTag(l)]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _num('max-$l', 'Max', suffix: 'kg')),
                          const SizedBox(width: 8),
                          Expanded(child: _num('target-$l', 'Target')),
                          const SizedBox(width: 8),
                          Expanded(child: _num('stretch-$l', 'Stretch')),
                        ]),
                        const SizedBox(height: 14),
                      ],
                      T('MEET WEIGHT RANGE', style: eyebrowStyle(context)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _num('bw-lo', 'Low', suffix: 'kg')),
                        const SizedBox(width: 8),
                        Expanded(child: _num('bw-hi', 'High', suffix: 'kg')),
                      ]),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: () => _save(store), child: const T('Save profile & maxes')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _gym(context, store, p),
                const SizedBox(height: 12),
                _programs(context, store, p),
                const SizedBox(height: 12),
                _backup(context, store, p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _language(BuildContext context, AppStore store) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const T('LANGUAGE · اللغة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 10),
        ValueListenableBuilder<String>(
          valueListenable: store.localeCode,
          builder: (context, code, _) => SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'system', label: Text(tr(context, 'Phone'))),
              const ButtonSegment(value: 'en', label: Text('English')),
              const ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {code},
            onSelectionChanged: (s) => store.setLocale(s.first),
          ),
        ),
      ]),
    );
  }

  Widget _account(BuildContext context, Palette p) {
    final cloud = CloudScope.of(context);
    final signedIn = cloud.signedIn;
    final sub = !signedIn
        ? 'Sign in to back up your data and use it on another phone.'
        : cloud.lastError != null
            ? cloud.lastError!
            : (cloud.syncing
                ? 'Syncing…'
                : (cloud.lastSynced == null ? 'Signed in' : 'Synced ${timeAgo(cloud.lastSynced!)}'));
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: signedIn ? p.navy : p.sunk,
              child: Icon(signedIn ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                  color: signedIn ? Colors.white : p.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(signedIn ? (cloud.user?.email ?? 'Account') : 'Account & cloud backup',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(color: cloud.lastError != null && signedIn ? p.warn : p.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right, color: p.muted),
          ]),
        ),
      ),
    );
  }

  Widget _gym(BuildContext context, AppStore store, Palette p) {
    final g = store.gym;
    String clock(int s) => s % 60 == 0 ? '${s ~/ 60} min' : fmtClock(s);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: T('GYM SETUP', style: headingStyle(context, size: 18))),
            TextButton.icon(
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const T('Calculators'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToolsScreen())),
            ),
          ]),
          const SizedBox(height: 4),
          T('Used for plate loading, warm-ups and the rest timer.', style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            value: [15.0, 20.0, 25.0].contains(g.bar) ? g.bar : 20.0,
            decoration: const InputDecoration(label: T('Bar')),
            items: const [
              DropdownMenuItem(value: 20.0, child: T('20 kg (men\'s / competition)')),
              DropdownMenuItem(value: 15.0, child: T('15 kg (women\'s)')),
              DropdownMenuItem(value: 25.0, child: T('25 kg (squat / specialty bar)')),
            ],
            onChanged: (v) => store.updateGym((x) => x.bar = v ?? 20.0),
          ),
          const SizedBox(height: 12),
          T('PLATES IN YOUR GYM', style: eyebrowStyle(context)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final kg in kAllPlates)
              FilterChip(
                label: Text(fmt(kg)),
                selected: g.plates.contains(kg),
                showCheckmark: false,
                avatar: CircleAvatar(backgroundColor: p.plate(kg), radius: 6),
                onSelected: (on) => store.updateGym((x) {
                  if (on) {
                    x.plates = [...x.plates, kg];
                  } else if (x.plates.length > 1) {
                    x.plates = x.plates.where((v) => v != kg).toList();
                  }
                }),
              ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const T('Competition collars (2.5 kg each)'),
            value: g.collars,
            onChanged: (v) => store.updateGym((x) => x.collars = v),
          ),
          const Divider(),
          const SizedBox(height: 8),
          T('REST TIMER', style: eyebrowStyle(context)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: g.restMain,
                decoration: const InputDecoration(label: T('Main lifts')),
                items: [
                  for (final sec in {120, 150, 180, 210, 240, 300, g.restMain}.toList()..sort())
                    DropdownMenuItem(value: sec, child: Text(clock(sec))),
                ],
                onChanged: (v) => store.updateGym((x) => x.restMain = v ?? 180),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: g.restAccessory,
                decoration: const InputDecoration(label: T('Accessories')),
                items: [
                  for (final sec in {45, 60, 75, 90, 120, 150, g.restAccessory}.toList()..sort())
                    DropdownMenuItem(value: sec, child: Text(clock(sec))),
                ],
                onChanged: (v) => store.updateGym((x) => x.restAccessory = v ?? 90),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const T('Start the timer when I mark a set'),
            subtitle: const T('Tap the light next to a set. The phone vibrates when rest is over.'),
            value: g.autoRest,
            onChanged: (v) => store.updateGym((x) => x.autoRest = v),
          ),
        ],
      ),
    );
  }

  Widget _programs(BuildContext context, AppStore store, Palette p) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('PROGRAMS', style: headingStyle(context, size: 18)),
          const SizedBox(height: 8),
          for (final prog in store.programs.reversed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: prog.id == store.activeId ? p.sunk : Colors.transparent,
                border: Border.all(color: prog.id == store.activeId ? p.navy : p.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          LevelChip(prog.level),
                          if (prog.id == store.activeId) ...[
                            const SizedBox(width: 6),
                            T('ACTIVE', style: eyebrowStyle(context, color: p.red)),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(prog.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(
                          '${prog.weeks} weeks · from ${shortDate(prog.start)} · '
                          '${prog.workouts.where((w) => w.completed).length}/${prog.workouts.length} workouts done',
                          style: TextStyle(color: p.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Program options',
                    onSelected: (v) => _programMenu(context, store, prog, v),
                    itemBuilder: (_) => [
                      if (prog.id != store.activeId) const PopupMenuItem(value: 'switch', child: T('Make active')),
                      const PopupMenuItem(value: 'rename', child: T('Rename')),
                      const PopupMenuItem(value: 'delete', child: T('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const T('Start a new program'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgramPickerScreen())),
          ),
        ],
      ),
    );
  }

  Future<void> _programMenu(BuildContext context, AppStore store, Program prog, String v) async {
    if (v == 'switch') {
      store.switchProgram(prog.id);
      toast(context, '${prog.name} is now active.');
    } else if (v == 'rename') {
      final t = await promptText(context, title: 'Rename program', label: 'Name', initial: prog.name);
      if (t != null && t.trim().isNotEmpty) store.renameProgram(prog.id, t.trim());
    } else if (v == 'delete') {
      final ok = await confirmDialog(context,
          title: 'Delete ${prog.name}?',
          body: 'All workouts and logs in this program are deleted. Body entries are kept.',
          action: 'Delete',
          danger: true);
      if (ok) store.deleteProgram(prog.id);
    }
  }

  Widget _backup(BuildContext context, AppStore store, Palette p) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('BACKUP', style: headingStyle(context, size: 18)),
          const SizedBox(height: 4),
          Text(
            'Everything is saved on this phone only. Copy a backup now and then and keep it somewhere safe, '
            'like a note or an email to yourself. Restore it here on a new phone.',
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const T('Copy backup'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: store.exportJson()));
                if (context.mounted) toast(context, 'Backup copied.');
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore, size: 16),
              label: const T('Restore backup'),
              onPressed: () => _restore(context, store),
            ),
          ]),
          const SizedBox(height: 14),
          T('EXPORT FOR SPREADSHEETS', style: eyebrowStyle(context)),
          const SizedBox(height: 4),
          T('Copies CSV text. Paste it into Excel, Google Sheets or a Python notebook.',
              style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const T('Copy sets (CSV)'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: store.exportSetsCsv()));
                if (context.mounted) toast(context, 'Sets copied as CSV.');
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.monitor_weight_outlined, size: 16),
              label: const T('Copy body data (CSV)'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: store.exportBodyCsv()));
                if (context.mounted) toast(context, 'Body data copied as CSV.');
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, AppStore store) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Restore backup'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const T('Paste the backup text. It replaces everything currently in the app.'),
              const SizedBox(height: 10),
              TextField(
                controller: ctl,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(hintText: '{ "version": 2, ... }'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.of(ctx).red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const T('Replace my data'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = store.importJson(ctl.text);
    if (done) {
      _dirty = false;
      _fill(store.profile);
      loadedRevision = store.revision;
      setState(() {});
    }
    if (context.mounted) {
      toast(context, done ? 'Backup restored.' : 'That text is not a Meet Prep Log backup. Nothing was changed.');
    }
  }
}
