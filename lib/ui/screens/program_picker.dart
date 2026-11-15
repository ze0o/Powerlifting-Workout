// Choose a program template for your level, then pick a start date.
import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/store.dart';
import '../../core/templates.dart';
import '../theme.dart';
import '../widgets.dart';

class ProgramPickerScreen extends StatelessWidget {
  const ProgramPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a program')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Every program is a starting point. After you start it you can change dates, '
            'add or remove exercises, and copy weeks.',
            style: TextStyle(color: p.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          for (final t in kTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: p.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StartProgramScreen(template: t))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          LevelChip(t.level),
                          const Spacer(),
                          Text(t.customWeeks ? 'Any length' : '${t.weeks} weeks',
                              style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ]),
                        const SizedBox(height: 8),
                        Text(t.name.toUpperCase(), style: headingStyle(context, size: 20)),
                        const SizedBox(height: 2),
                        Text(t.frequency, style: TextStyle(color: p.muted, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(t.summary, style: const TextStyle(fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StartProgramScreen extends StatefulWidget {
  final ProgramTemplate template;
  const StartProgramScreen({super.key, required this.template});

  @override
  State<StartProgramScreen> createState() => _StartProgramScreenState();
}

class _StartProgramScreenState extends State<StartProgramScreen> {
  late final TextEditingController name;
  String start = todayIso();
  int weeks = 8;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.template.name);
    weeks = widget.template.weeks;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final t = widget.template;
    final m = store.profile.maxes;
    return Scaffold(
      appBar: AppBar(title: Text('Start ${t.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Program name')),
          const SizedBox(height: 16),
          Text('FIRST DAY', style: eyebrowStyle(context)),
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
          Text(t.startHint, style: TextStyle(color: p.muted, fontSize: 12.5)),
          if (t.customWeeks) ...[
            const SizedBox(height: 16),
            Text('LENGTH: $weeks WEEKS', style: eyebrowStyle(context)),
            Slider(
              value: weeks.toDouble(),
              min: 1,
              max: 16,
              divisions: 15,
              label: '$weeks',
              onChanged: (v) => setState(() => weeks = v.round()),
            ),
          ],
          const SizedBox(height: 16),
          Panel(
            child: Text(
              'Targets use your current maxes: squat ${fmt(m['squat'] ?? 0)}, bench ${fmt(m['bench'] ?? 0)}, '
              'deadlift ${fmt(m['deadlift'] ?? 0)} kg. Change them any time in the Athlete tab and every target updates.\n\n'
              'Your current program and its logs stay saved. You can switch back from the Athlete tab.',
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final label = name.text.trim().isEmpty ? t.name : name.text.trim();
              store.startProgram(t, start, weeks, name.text);
              Navigator.of(context).popUntil((r) => r.isFirst);
              messenger.showSnackBar(SnackBar(content: Text('$label started.')));
            },
            child: const Text('Start program'),
          ),
        ],
      ),
    );
  }
}
