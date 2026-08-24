import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF2E7D6B); // calm teal-green: money + savings

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainerLow,
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// Semantic colors used across charts and lists.
  static Color incomeColor(BuildContext c) => Theme.of(c).colorScheme.brightness ==
          Brightness.dark
      ? const Color(0xFF66BB6A)
      : const Color(0xFF2E7D32);

  static Color expenseColor(BuildContext c) =>
      Theme.of(c).colorScheme.brightness == Brightness.dark
          ? const Color(0xFFEF5350)
          : const Color(0xFFC62828);

  static Color savingsColor(BuildContext c) => const Color(0xFF1E88E5);
}
