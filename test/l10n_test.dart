import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meet_prep_log/core/calc.dart';
import 'package:meet_prep_log/l10n/ar.dart';
import 'package:meet_prep_log/l10n/l10n.dart';

void main() {
  test('every Arabic entry keeps the same placeholders as its English key', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in kAr.entries) {
      final a = ph.allMatches(e.key).map((m) => m.group(1)).toSet();
      final b = ph.allMatches(e.value).map((m) => m.group(1)).toSet();
      expect(b, a, reason: 'Placeholders differ for "${e.key}"');
      expect(e.value.trim(), isNotEmpty, reason: 'Empty translation for "${e.key}"');
    }
  });

  testWidgets('texts switch to Arabic and fall back to English', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Column(children: [
          const T('Program'),
          Text(tr(context, 'WEEK {n}', {'n': 3})),
          const T('Not in the dictionary'),
          Text(Directionality.of(context) == TextDirection.rtl ? 'rtl' : 'ltr'),
        ]),
      ),
    ));
    expect(find.text('البرنامج'), findsOneWidget);
    expect(find.text('الأسبوع 3'), findsOneWidget);
    expect(find.text('Not in the dictionary'), findsOneWidget);
    expect(find.text('rtl'), findsOneWidget);
  });

  test('Arabic month and weekday names', () {
    dateLang = 'ar';
    expect(shortDate('2026-11-12'), '12 نوفمبر');
    expect(weekdayName('2026-11-12'), 'الخميس');
    dateLang = 'en';
    expect(shortDate('2026-11-12'), 'Nov 12');
  });
}
