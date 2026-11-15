// Competition style: navy scoreboard headers with a red stripe, white cards,
// referee lights (white = good lift, red = no lift) and plate colours per lift.
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

class Palette {
  final Color bg, surface, sunk, ink, muted, line;
  final Color navy, onNavy, navyMuted, red, blue;
  final Color squat, bench, deadlift, ok, warn;
  final List<Color> plates; // 25, 20, 15, 10, 5, 2.5, 1.25 kg

  const Palette({
    required this.bg,
    required this.surface,
    required this.sunk,
    required this.ink,
    required this.muted,
    required this.line,
    required this.navy,
    required this.onNavy,
    required this.navyMuted,
    required this.red,
    required this.blue,
    required this.squat,
    required this.bench,
    required this.deadlift,
    required this.ok,
    required this.warn,
    required this.plates,
  });

  /// Competition plate colours. Small change plates reuse the colour of their big sibling.
  Color plate(double kg) {
    final map = <double, int>{25.0: 0, 20.0: 1, 15.0: 2, 10.0: 3, 5.0: 4, 2.5: 5, 2.0: 1, 1.5: 2, 1.25: 6, 1.0: 3, 0.5: 4, 0.25: 6};
    return plates[map[kg] ?? 6];
  }

  Color lift(String? l) => l == 'squat'
      ? squat
      : l == 'bench'
          ? bench
          : l == 'deadlift'
              ? deadlift
              : muted;

  static const light = Palette(
    bg: Color(0xFFEEF1F5),
    surface: Color(0xFFFFFFFF),
    sunk: Color(0xFFE3E8EF),
    ink: Color(0xFF0E1A2B),
    muted: Color(0xFF5A6678),
    line: Color(0xFFD3DAE4),
    navy: Color(0xFF0C2340),
    onNavy: Color(0xFFFFFFFF),
    navyMuted: Color(0xFFA9B8CF),
    red: Color(0xFFC8102E),
    blue: Color(0xFF1F5FBF),
    squat: Color(0xFFC8102E),
    bench: Color(0xFF1F5FBF),
    deadlift: Color(0xFFA27300),
    ok: Color(0xFF1E7B45),
    warn: Color(0xFFB4470C),
    plates: [
      Color(0xFFC8102E),
      Color(0xFF1F5FBF),
      Color(0xFFE0B000),
      Color(0xFF1E8A4C),
      Color(0xFFF7F7F4),
      Color(0xFF1C2230),
      Color(0xFFB8C0CA),
    ],
  );

  static const dark = Palette(
    bg: Color(0xFF0A0F18),
    surface: Color(0xFF121A27),
    sunk: Color(0xFF1A2433),
    ink: Color(0xFFE7ECF3),
    muted: Color(0xFF97A3B6),
    line: Color(0xFF263243),
    navy: Color(0xFF0B1A30),
    onNavy: Color(0xFFFFFFFF),
    navyMuted: Color(0xFF8FA2BF),
    red: Color(0xFFF0505F),
    blue: Color(0xFF6E9CF0),
    squat: Color(0xFFF0505F),
    bench: Color(0xFF6E9CF0),
    deadlift: Color(0xFFE2B53C),
    ok: Color(0xFF4CC07A),
    warn: Color(0xFFF0954F),
    plates: [
      Color(0xFFE0404F),
      Color(0xFF4A7FE8),
      Color(0xFFE7BB3A),
      Color(0xFF3FAE63),
      Color(0xFFE9E9E6),
      Color(0xFF05080D),
      Color(0xFF8E979E),
    ],
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final p = dark ? Palette.dark : Palette.light;
  final primary = dark ? p.blue : p.navy;
  final onPrimary = dark ? p.bg : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0C2340), brightness: b).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: p.red,
    onSecondary: Colors.white,
    surface: p.surface,
    onSurface: p.ink,
    outline: p.line,
    error: p.red,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final radius = BorderRadius.circular(6);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.navy,
      foregroundColor: p.onNavy,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: .4, color: p.onNavy),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.blue, width: 2)),
      hintStyle: TextStyle(color: p.muted.withAlpha(170)),
      labelStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: dark ? p.blue : p.navy)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.navy,
      indicatorColor: Colors.white.withAlpha(36),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? Colors.white : p.navyMuted,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : p.navyMuted)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.navy,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.sunk,
      side: BorderSide(color: p.line),
      labelStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
  );
}

/// Heavy uppercase heading, scoreboard style.
/// Letter spacing breaks Arabic joining, so it is turned off in right-to-left text.
double spacing(BuildContext context, double v) => Directionality.of(context) == TextDirection.rtl ? 0 : v;

TextStyle headingStyle(BuildContext context, {double size = 22, Color? color}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: spacing(context, 0.5),
      height: 1.05,
      color: color ?? Palette.of(context).ink,
    );

TextStyle eyebrowStyle(BuildContext context, {Color? color}) => TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: spacing(context, 1.4),
      color: color ?? Palette.of(context).muted,
    );
