import 'package:flutter/material.dart';

import 'app_space.dart';

/// Material 3 light and dark themes built from the app icon's palette.
///
/// Surfaces are the icon's navy (dark) and a cool blue-grey (light). Coral-pink,
/// from the icon's calendar header, is the one brand accent. Orange marks
/// birthdays and pink marks anniversaries, as on the icon.
///
/// The scheme is set explicitly rather than with [ColorScheme.fromSeed]: a coral
/// seed tints every neutral warm, which is what made dark mode look brown.
class AppTheme {
  /// Icon header gradient, for hero surfaces such as onboarding.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A5B), Color(0xFFFF6B9D)],
  );

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ColorScheme scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6B9D),
      brightness: brightness,
    );
    if (brightness == Brightness.dark) {
      return base.copyWith(
        primary: const Color(0xFFFF7E95),
        onPrimary: const Color(0xFF33101C),
        primaryContainer: const Color(0xFF5A2338),
        onPrimaryContainer: const Color(0xFFFFD9E2),
        secondary: const Color(0xFFAFBBE8),
        onSecondary: const Color(0xFF1A2140),
        secondaryContainer: const Color(0xFF343E61),
        onSecondaryContainer: const Color(0xFFE3E8FF),
        tertiary: const Color(0xFFFFAA74),
        onTertiary: const Color(0xFF3A1A06),
        tertiaryContainer: const Color(0xFF5C3418),
        onTertiaryContainer: const Color(0xFFFFDCC6),
        error: const Color(0xFFFF8A80),
        onError: const Color(0xFF3B0A08),
        surface: const Color(0xFF151824),
        onSurface: const Color(0xFFECEEF5),
        onSurfaceVariant: const Color(0xFFA6ACC0),
        surfaceDim: const Color(0xFF11131D),
        surfaceBright: const Color(0xFF383F57),
        surfaceContainerLowest: const Color(0xFF10121B),
        surfaceContainerLow: const Color(0xFF1E2232),
        surfaceContainer: const Color(0xFF232838),
        surfaceContainerHigh: const Color(0xFF2A3043),
        surfaceContainerHighest: const Color(0xFF333A50),
        outline: const Color(0xFF6A7189),
        outlineVariant: const Color(0xFF343A4F),
        inverseSurface: const Color(0xFFECEEF5),
        onInverseSurface: const Color(0xFF1E2232),
        inversePrimary: const Color(0xFFC42F5C),
        surfaceTint: Colors.transparent,
        shadow: Colors.black,
        scrim: Colors.black,
      );
    }
    return base.copyWith(
      primary: const Color(0xFFC42F5C),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE0E8),
      onPrimaryContainer: const Color(0xFF5C0F29),
      secondary: const Color(0xFF4A5888),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE1E6F8),
      onSecondaryContainer: const Color(0xFF1C2546),
      tertiary: const Color(0xFFA2441A),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFFE3D2),
      onTertiaryContainer: const Color(0xFF4A1C05),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: const Color(0xFFF5F6FA),
      onSurface: const Color(0xFF191C28),
      onSurfaceVariant: const Color(0xFF4B5267),
      surfaceDim: const Color(0xFFDCDFE8),
      surfaceBright: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFEEF0F6),
      surfaceContainerHigh: const Color(0xFFE8EBF2),
      surfaceContainerHighest: const Color(0xFFE0E4EC),
      outline: const Color(0xFF8A90A4),
      outlineVariant: const Color(0xFFDADEE8),
      inverseSurface: const Color(0xFF232838),
      onInverseSurface: const Color(0xFFECEEF5),
      inversePrimary: const Color(0xFFFF7E95),
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = AppTheme.scheme(brightness);
    final text = _text(scheme);
    final buttonText = WidgetStatePropertyAll(text.labelLarge);
    final minSize = const WidgetStatePropertyAll(Size(AppSpace.touch, AppSpace.touch));
    final button = ButtonStyle(
      minimumSize: minSize,
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: buttonText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      primaryTextTheme: text,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSpace.touch, AppSpace.touch),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        extendedTextStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
        labelStyle: text.labelLarge,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.sm)),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: AppSpace.touch,
        minVerticalPadding: AppSpace.sm,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        iconColor: scheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.sm),
          borderSide: BorderSide(color: scheme.outline),
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// Material 3 type scale. Sizes are the unscaled dp values; text scale grows them.
  static TextTheme _text(ColorScheme scheme) {
    TextStyle style(double size, FontWeight weight, double height) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: scheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: style(57, FontWeight.w400, 1.12),
      displayMedium: style(45, FontWeight.w400, 1.16),
      displaySmall: style(36, FontWeight.w400, 1.22),
      headlineLarge: style(32, FontWeight.w600, 1.25),
      headlineMedium: style(28, FontWeight.w600, 1.29),
      headlineSmall: style(24, FontWeight.w600, 1.33),
      titleLarge: style(22, FontWeight.w600, 1.27),
      titleMedium: style(16, FontWeight.w600, 1.50),
      titleSmall: style(14, FontWeight.w600, 1.43),
      bodyLarge: style(16, FontWeight.w400, 1.50),
      bodyMedium: style(14, FontWeight.w400, 1.43),
      bodySmall: style(12, FontWeight.w400, 1.33),
      labelLarge: style(14, FontWeight.w600, 1.43),
      labelMedium: style(12, FontWeight.w600, 1.33),
      labelSmall: style(11, FontWeight.w600, 1.45),
    );
  }
}

/// Colors for built-in birthdays (orange) and anniversaries (pink), from the icon.
/// Text colors meet WCAG AA (4.5:1) on both themes' cards.
class EventPalette {
  static Color accent(BuildContext context, {required bool birthday}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (birthday) {
      return dark ? const Color(0xFFFFAA74) : const Color(0xFFA2441A);
    }
    return dark ? const Color(0xFFFF9DC0) : const Color(0xFFB02457);
  }

  /// Soft fill behind an event's icon, derived from its accent.
  static Color tint(BuildContext context, Color accent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return accent.withValues(alpha: dark ? 0.16 : 0.12);
  }
}
