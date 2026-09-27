import 'package:flutter/material.dart';

class AppColors {
  static const indigo = Color(0xFF4F46E5),
      teal = Color(0xFF0F766E),
      violet = Color(0xFF8B5CF6),
      ink = Color(0xFF0F172A),
      muted = Color(0xFF64748B),
      line = Color(0xFFE2E8F0),
      background = Color(0xFFF8FAFC),
      red = Color(0xFFB91C1C),
      amber = Color(0xFFB45309);
}

ThemeData appTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0F172A)
        : AppColors.background,
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: dark ? Colors.white : AppColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
      ),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF111827) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark
              ? const Color(0xFF263247)
              : AppColors.line.withValues(alpha: .8),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 50),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      selectedColor: dark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF111827) : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF263247) : AppColors.line,
      space: 32,
    ),
  );
}
