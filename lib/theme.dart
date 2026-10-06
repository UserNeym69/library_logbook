import 'package:flutter/material.dart';

// ONE accent color: school navy (a lighter blue in dark mode).
// Red is only used for risky actions like Delete.
const navy = Color(0xFF0B335E);
const deepNavy = Color(0xFF06214A);
const danger = Color(0xFFC62828);
const gold = Color(0xFFF9D458); // no longer used in the design

ThemeData icctTheme() => _build(Brightness.light);
ThemeData icctDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFF8DB8F0) : navy;
  final onAccent = dark ? deepNavy : Colors.white;
  final card = dark ? const Color(0xFF17202B) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: navy, brightness: b).copyWith(
    primary: accent,
    onPrimary: onAccent,
    error: dark ? const Color(0xFFEF9A9A) : danger,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? card : navy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? Colors.white12 : Colors.black12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: card),
    chipTheme: ChipThemeData(
      selectedColor: accent.withAlpha(45),
      checkmarkColor: accent,
      backgroundColor: card,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: accent.withAlpha(45),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
