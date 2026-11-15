// `flutter create` puts a counter-app test here. This app's real tests are in
// core_test.dart and l10n_test.dart; this one only checks that both themes build.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meet_prep_log/ui/theme.dart';

void main() {
  testWidgets('light and dark themes build', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(MaterialApp(theme: buildTheme(b), home: const Scaffold(body: Text('ok'))));
      expect(find.text('ok'), findsOneWidget);
    }
  });
}
