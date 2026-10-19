import 'package:flutter/material.dart';

const macroCarbColor = Color(0xFFFFB020);
const macroFatColor = Color(0xFFEF6C57);

/// Colour per activity id, used on the Progress calendar and Activity cards.
const activityColors = <String, Color>{
  'steps': Color(0xFF2E9E5B),
  'strength': Color(0xFFD6336C),
  'cardio': Color(0xFFF08A24),
  'cycling': Color(0xFF2F7DE1),
  'elliptical': Color(0xFF8E5BD6),
  'yoga': Color(0xFF14A3A3),
};
const restColor = Color(0xFF6B7A99);

ThemeData buildTheme() {
  const seed = Color(0xFF2F9BF0);
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  OutlineInputBorder border([Color? c]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c ?? Colors.transparent, width: 1.5),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(scheme.primary),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
