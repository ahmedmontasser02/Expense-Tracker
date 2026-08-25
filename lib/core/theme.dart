import 'package:flutter/material.dart';

/// Two design systems, mapped to brightness:
///   Light = "Fortress Finance" — trust-teal corporate, flat bordered cards,
///            Hanken Grotesk headlines / Inter body / JetBrains Mono labels.
///   Dark  = "Neon Tokyo" — near-black surfaces, hot-pink + cyan accents with
///            soft glows, Sora headlines / Inter body / Space Grotesk labels.
class AppTheme {
  AppTheme._();

  // ----- Fortress Finance (light) -----
  static const _fPrimary = Color(0xFF003441);
  static const _fOnPrimary = Color(0xFFFFFFFF);
  static const _fPrimaryContainer = Color(0xFF0F4C5C);
  static const _fOnPrimaryContainer = Color(0xFFDFF0F6);
  static const _fSecondary = Color(0xFF00677D);
  static const _fTertiary = Color(0xFF482700);
  static const _fTertiaryContainer = Color(0xFF623D13);
  static const _fOnTertiaryContainer = Color(0xFFDDA975);
  static const _fError = Color(0xFFBA1A1A);
  static const _fSurface = Color(0xFFF9F9FA);
  static const _fOnSurface = Color(0xFF191C1D);
  static const _fOnSurfaceVariant = Color(0xFF40484B);
  static const _fOutline = Color(0xFF70787C);
  static const _fOutlineVariant = Color(0xFFC0C8CB);
  static const _fCard = Color(0xFFFFFFFF);
  static const _fCardBorder = Color(0xFFE2E8F0);
  static const _fInverseSurface = Color(0xFF2E3132);
  static const _fOnInverseSurface = Color(0xFFF0F1F2);

  // ----- Neon Tokyo (dark) -----
  static const _nBg = Color(0xFF0A0A12);
  static const _nOnSurface = Color(0xFFF2F2F7);
  static const _nOnSurfaceVariant = Color(0xFF9A9AB0);
  static const _nPink = Color(0xFFFF2D78);
  static const _nOnPink = Color(0xFF14060C);
  static const _nCyan = Color(0xFF00FFCC);
  static const _nYellow = Color(0xFFFFE04A);
  static const _nCard = Color(0xFF12121D);
  static const _nCardBorder = Color(0xFF262637);
  static const _nContainerLow = Color(0xFF101019);
  static const _nContainer = Color(0xFF161622);
  static const _nContainerHigh = Color(0xFF1E1E2C);
  static const _nContainerHighest = Color(0xFF282838);
  static const _nOutline = Color(0xFF54546A);
  static const _nOutlineVariant = Color(0xFF2A2A3C);
  static const _nError = Color(0xFFFF5C70);
  static const _nErrorContainer = Color(0xFF4A0E1A);
  static const _nOnErrorContainer = Color(0xFFFFD9DD);

  // ----- Semantic colors (per mode) -----
  static const _fIncome = Color(0xFF2D6A4F);
  static const _fExpense = Color(0xFFBC4749);
  static const _fSavings = Color(0xFF457B9D);
  static const _nIncome = _nCyan;
  static const _nExpense = Color(0xFFFF5C5C);
  static const _nSavings = _nYellow;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final display = isLight ? 'HankenGrotesk' : 'Sora';
    final label = isLight ? 'JetBrainsMono' : 'SpaceGrotesk';

    final scheme = isLight
        ? const ColorScheme.light(
            primary: _fPrimary,
            onPrimary: _fOnPrimary,
            primaryContainer: _fPrimaryContainer,
            onPrimaryContainer: _fOnPrimaryContainer,
            secondary: _fSecondary,
            onSecondary: _fOnPrimary,
            secondaryContainer: _fPrimaryContainer,
            onSecondaryContainer: _fOnPrimaryContainer,
            tertiary: _fTertiary,
            onTertiary: _fOnPrimary,
            tertiaryContainer: _fTertiaryContainer,
            onTertiaryContainer: _fOnTertiaryContainer,
            error: _fError,
            surface: _fSurface,
            onSurface: _fOnSurface,
            onSurfaceVariant: _fOnSurfaceVariant,
            outline: _fOutline,
            outlineVariant: _fOutlineVariant,
            inverseSurface: _fInverseSurface,
            onInverseSurface: _fOnInverseSurface,
            surfaceContainerLowest: _fCard,
            surfaceContainerLow: Color(0xFFF3F4F5),
            surfaceContainer: Color(0xFFEDEEEF),
            surfaceContainerHigh: Color(0xFFE7E8E9),
            surfaceContainerHighest: Color(0xFFE1E2E4),
          )
        : const ColorScheme.dark(
            primary: _nPink,
            onPrimary: _nOnPink,
            primaryContainer: Color(0xFF3A1026),
            onPrimaryContainer: Color(0xFFFFB1CE),
            secondary: _nCyan,
            onSecondary: Color(0xFF00291F),
            secondaryContainer: Color(0xFF00443A),
            onSecondaryContainer: Color(0xFF8FFFE6),
            tertiary: _nYellow,
            onTertiary: Color(0xFF241C00),
            tertiaryContainer: Color(0xFF4A3D00),
            onTertiaryContainer: Color(0xFFFFEFA0),
            error: _nError,
            errorContainer: _nErrorContainer,
            onErrorContainer: _nOnErrorContainer,
            surface: _nBg,
            onSurface: _nOnSurface,
            onSurfaceVariant: _nOnSurfaceVariant,
            outline: _nOutline,
            outlineVariant: _nOutlineVariant,
            inverseSurface: Color(0xFFE6E6EF),
            onInverseSurface: Color(0xFF14141D),
            surfaceContainerLowest: Color(0xFF050508),
            surfaceContainerLow: _nContainerLow,
            surfaceContainer: _nContainer,
            surfaceContainerHigh: _nContainerHigh,
            surfaceContainerHighest: _nContainerHighest,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(display, label, scheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isLight ? _fPrimary : _nPink,
          shadows: isLight
              ? null
              : const [
                  Shadow(color: Color(0x66FF2D78), blurRadius: 14),
                ],
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? _fCard : _nCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isLight ? _fCardBorder : _nCardBorder),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? _fCardBorder : _nOutlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? _fCard : _nContainer,
        isDense: true,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isLight ? _fCardBorder : _nOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isLight ? _fCardBorder : _nOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(
            color: isLight ? _fOutlineVariant : _nOutlineVariant),
        backgroundColor: isLight ? _fCard : _nContainer,
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: TextStyle(
          fontFamily: label,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: label,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: scheme.onSecondaryContainer,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(const StadiumBorder().copyWith(
              side: BorderSide(
                  color: isLight ? _fOutlineVariant : _nOutlineVariant))),
          side: WidgetStatePropertyAll(BorderSide(
              color: isLight ? _fOutlineVariant : _nOutlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? (isLight ? _fCard : _nPink)
                  : (isLight ? const Color(0xFFEDEEEF) : _nContainer)),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? (isLight ? _fPrimary : _nOnPink)
                  : scheme.onSurfaceVariant),
          textStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: isLight ? 'Inter' : 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          )),
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: isLight ? _fSurface : const Color(0xFF0C0C15),
        indicatorColor: isLight
            ? _fPrimary.withValues(alpha: .08)
            : _nPink.withValues(alpha: .12),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: label,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: isLight ? 0 : 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: TextStyle(
            fontFamily: label,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: .6,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isLight ? _fInverseSurface : _nContainerHigh,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: isLight ? _fOnInverseSurface : _nOnSurface,
        ),
        actionTextColor: isLight ? const Color(0xFF7BD8AC) : _nCyan,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? _fCard : _nContainer,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontFamily: display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : (isLight ? _fCard : _nOnSurfaceVariant)),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary
                : (isLight ? _fOutlineVariant : _nOutline)),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.transparent
                : (isLight ? _fOutlineVariant : _nOutline)),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: scheme.primary),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: isLight ? 'JetBrainsMono' : 'SpaceGrotesk',
          fontSize: 11.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static TextTheme _textTheme(String display, String label, ColorScheme s) {
    final bodyColor = s.onSurface;
    return TextTheme(
      displayLarge: TextStyle(
          fontFamily: display,
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: bodyColor),
      displayMedium: TextStyle(
          fontFamily: display,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          color: bodyColor),
      displaySmall: TextStyle(
          fontFamily: display,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
          color: bodyColor),
      headlineLarge: TextStyle(
          fontFamily: display,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: bodyColor),
      headlineMedium: TextStyle(
          fontFamily: display,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: bodyColor),
      headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: bodyColor),
      titleLarge: TextStyle(
          fontFamily: display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: bodyColor),
      titleMedium: TextStyle(
          fontFamily: display,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: bodyColor),
      titleSmall: TextStyle(
          fontFamily: display,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: bodyColor),
      bodyLarge: TextStyle(
          fontFamily: 'Inter', fontSize: 16, color: bodyColor),
      bodyMedium: TextStyle(
          fontFamily: 'Inter', fontSize: 14, color: bodyColor),
      bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: s.onSurfaceVariant),
      labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: bodyColor),
      labelMedium: TextStyle(
          fontFamily: label,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .6,
          color: bodyColor),
      labelSmall: TextStyle(
          fontFamily: label,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
          color: s.onSurfaceVariant),
    );
  }

  /// Mono-spaced-feel caps label (dates, metadata, section eyebrows).
  static TextStyle labelCaps(BuildContext c, {Color? color}) {
    final b = Theme.of(c).brightness;
    return TextStyle(
      fontFamily: b == Brightness.light ? 'JetBrainsMono' : 'SpaceGrotesk',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: .8,
      color: color ?? Theme.of(c).colorScheme.onSurfaceVariant,
    );
  }

  /// Soft neon glow shadow list; null in light mode (no glow).
  static List<BoxShadow>? glow(BuildContext c, Color color,
          {double radius = 16, double alpha = .35}) =>
      Theme.of(c).brightness == Brightness.dark
          ? [BoxShadow(color: color.withValues(alpha: alpha), blurRadius: radius)]
          : null;

  /// Semantic colors used across charts and lists.
  static Color incomeColor(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light ? _fIncome : _nIncome;

  static Color expenseColor(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light ? _fExpense : _nExpense;

  static Color savingsColor(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light ? _fSavings : _nSavings;

  /// Balance card gradient: teal ramp (light) / dark violet container (dark).
  static Gradient balanceGradient(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
          ? const LinearGradient(
              colors: [_fPrimaryContainer, _fPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFF241426), Color(0xFF14121F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );
}
