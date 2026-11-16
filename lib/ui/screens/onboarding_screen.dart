// First-run welcome: about you, your maxes (or an estimate), and a program.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/templates.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_screen.dart';
import '../../l10n/l10n.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final c = <String, TextEditingController>{};
  String sex = 'male';
  String division = 'classic';
  String weightClass = '105';
  String federation = 'ipf';
  String templateId = 'meet-prep-8';
  String start = todayIso();
  int customWeeks = 8;

  // estimate helper
  String estLift = 'squat';
  final estW = TextEditingController();
  final estR = TextEditingController(text: '5');
  final estRpe = TextEditingController(text: '8');

  TextEditingController _ctl(String k, [String initial = '']) =>
      c.putIfAbsent(k, () => TextEditingController(text: initial));

  List<String> get _classes => federationById(federation).classes(sex == 'female');

  void _remapClass() {
    if (!_classes.contains(weightClass)) {
      weightClass = fitClass(_classes, double.tryParse(weightClass.replaceAll('+', '')));
    }
  }

  @override
  void dispose() {
    for (final t in [...c.values, estW, estR, estRpe]) {
      t.dispose();
    }
    super.dispose();
  }

  Widget _num(String key, String label, {String suffix = 'kg', String initial = ''}) => TextField(
        controller: _ctl(key, initial),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: tr(context, label), suffixText: suffix),
      );

  void _next() {
    FocusScope.of(context).unfocus();
    if (step == 1) {
      for (final l in kLifts) {
        final v = parseNum(_ctl('max-$l').text);
        if (v == null || v <= 0) {
          toast(context, 'Enter a max for all three lifts, or use the estimate below.');
          return;
        }
      }
    }
    if (step < 2) {
      setState(() => step++);
    } else {
      _finish();
    }
  }

  void _finish() {
    final store = StoreScope.read(context);
    final maxes = {for (final l in kLifts) l: parseNum(_ctl('max-$l').text)!};
    final goals = {for (final l in kLifts) l: [r25(maxes[l]! * 1.05), r25(maxes[l]! * 1.08)]};
    final bw = parseNum(_ctl('bw').text);
    final limit = double.tryParse(weightClass);
    final lo = limit == null ? (bw ?? 120) - 2 : limit - 5;
    final hi = limit == null ? (bw ?? 120) + 2 : limit - 2;
    final profile = Profile(
      name: _ctl('name').text.trim(),
      sex: sex,
      heightCm: parseNum(_ctl('height').text) ?? 175,
      division: division,
      weightClass: weightClass,
      federation: federation,
      maxes: maxes,
      goals: goals,
      bwTarget: [lo, hi],
    );
    final t = templateById(templateId);
    store.completeOnboarding(profile, t, start, t.customWeeks ? customWeeks : t.weeks, bw);
  }

  void _useEstimate() {
    final e = estimatedMax(estW.text, estR.text, estRpe.text);
    if (e == null) {
      toast(context, 'Enter a weight and 1–12 reps.');
      return;
    }
    setState(() => _ctl('max-$estLift').text = fmt(r25(e)));
    toast(context, '${kLiftNames[estLift]} max set to ${fmt(r25(e))} kg.');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const titles = ['ABOUT YOU', 'YOUR MAXES', 'YOUR PROGRAM'];
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            eyebrow: 'STEP ${step + 1} OF 3 · MEET PREP LOG',
            title: titles[step],
            bottom: Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    height: 4,
                    color: i <= step ? p.red : Colors.white.withAlpha(40),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (step == 0) ..._about(context, p),
                  if (step == 1) ..._maxes(context, p),
                  if (step == 2) ..._program(context, p),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                if (step > 0) TextButton(onPressed: () => setState(() => step--), child: const T('Back')),
                const Spacer(),
                FilledButton(onPressed: _next, child: Text(step < 2 ? 'Next' : 'Start training')),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _about(BuildContext context, Palette p) => [
        const T('Welcome. A few details so targets, weight classes and GL points fit you.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const T('Already have an account? Sign in and restore'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctl('name'),
          textCapitalization: TextCapitalization.words,
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
            _remapClass();
          }),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'classic', label: T('Classic (raw)')),
            ButtonSegment(value: 'equipped', label: T('Equipped')),
          ],
          selected: {division},
          onSelectionChanged: (s) => setState(() => division = s.first),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _num('bw', 'Bodyweight')),
          const SizedBox(width: 10),
          Expanded(child: _num('height', 'Height', suffix: 'cm')),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: federation,
          isExpanded: true,
          decoration: const InputDecoration(label: T('Federation')),
          items: [for (final f in kFederations) DropdownMenuItem(value: f.id, child: Text(f.name))],
          onChanged: (v) => setState(() {
            federation = v ?? federation;
            _remapClass();
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('class-$federation-$sex'),
          value: _classes.contains(weightClass) ? weightClass : fitClass(_classes, null),
          decoration: const InputDecoration(label: T('Weight class you want to compete in')),
          items: [
            for (final k in _classes) DropdownMenuItem(value: k, child: Text(k.endsWith('+') ? '$k kg' : '−$k kg')),
          ],
          onChanged: (v) => setState(() => weightClass = v ?? weightClass),
        ),
        const SizedBox(height: 4),
        T('Not sure? Pick IPF: it is the biggest drug-tested federation. You can change any of this later in the Athlete tab.',
            style: TextStyle(color: p.muted, fontSize: 12)),
      ];

  List<Widget> _maxes(BuildContext context, Palette p) => [
        const T('Your current one-rep maxes. Every percentage in your program is based on these.'),
        const SizedBox(height: 16),
        for (final l in kLifts) ...[
          Row(children: [
            SizedBox(width: 84, child: Align(alignment: Alignment.centerLeft, child: LiftTag(l))),
            Expanded(child: _num('max-$l', '${kLiftNames[l]} max')),
          ]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T("DON'T KNOW A MAX?", style: eyebrowStyle(context)),
              const SizedBox(height: 4),
              T('Enter a recent hard set and how hard it felt (RPE 10 = nothing left).',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: estLift,
                decoration: const InputDecoration(label: T('Lift')),
                items: [for (final l in kLifts) DropdownMenuItem(value: l, child: Text(kLiftNames[l]!))],
                onChanged: (v) => setState(() => estLift = v ?? 'squat'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: estW,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(label: T('Weight'), suffixText: 'kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: estR,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(label: T('Reps')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: estRpe,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(label: T('RPE')),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: _useEstimate, child: const T('Estimate and use it')),
              ),
            ],
          ),
        ),
      ];

  List<Widget> _program(BuildContext context, Palette p) => [
        const T('Pick a starting program. You can edit every workout after you start.'),
        const SizedBox(height: 12),
        for (final t in kTemplates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: templateId == t.id ? p.navy : p.line, width: templateId == t.id ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => templateId = t.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(templateId == t.id ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: templateId == t.id ? p.red : p.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          LevelChip(t.level),
                          const SizedBox(width: 8),
                          Text(t.customWeeks ? tr(context, 'Any length') : tr(context, '{n} weeks', {'n': t.weeks}),
                              style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 6),
                        Text(tr(context, t.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(tr(context, t.frequency), style: TextStyle(color: p.muted, fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Text(tr(context, t.summary), style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        T('FIRST DAY', style: eyebrowStyle(context)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(weekdayDate(start)),
            onPressed: () async {
              final d = await pickIsoDate(context, start, help: 'First day of week 1');
              if (d != null) setState(() => start = d);
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(tr(context, templateById(templateId).startHint), style: TextStyle(color: p.muted, fontSize: 12.5)),
        if (templateById(templateId).customWeeks) ...[
          const SizedBox(height: 12),
          Text('LENGTH: $customWeeks WEEKS', style: eyebrowStyle(context)),
          Slider(
            value: customWeeks.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            label: '$customWeeks',
            onChanged: (v) => setState(() => customWeeks = v.round()),
          ),
        ],
      ];
}
