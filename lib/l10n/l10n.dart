// Arabic / English. Strings are written in English in the code and looked up
// in the Arabic dictionary (ar.dart) when the app runs in Arabic. Anything not
// translated yet falls back to English, so a missing entry never breaks a screen.
import 'package:flutter/widgets.dart';

import 'ar.dart';

const List<Locale> kSupportedLocales = [Locale('en'), Locale('ar')];

bool isArabic(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

/// Translate [en]. Placeholders like {n} are filled from [args].
String tr(BuildContext context, String en, [Map<String, Object?> args = const {}]) {
  var s = isArabic(context) ? (kAr[en] ?? en) : en;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// A Text that translates itself. Drop-in for Text('literal') and still const.
class T extends StatelessWidget {
  final String en;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  const T(this.en, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap});

  @override
  Widget build(BuildContext context) => Text(
        tr(context, en),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      );
}
