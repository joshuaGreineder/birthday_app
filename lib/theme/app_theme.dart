import 'package:flutter/material.dart';

import 'app_space.dart';

/// Material 3 light and dark themes from one coral seed.
///
/// The seed matches the calendar icon header: coral into pink, with the pink
/// heart as part of that same accent rather than a second brand color.
class AppTheme {
  static const Color coral = Color(0xFFFF6F61);

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: brightness,
    );
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

/// Text colors for built-in birthdays and anniversaries.
/// Checked against the theme surfaces so they meet WCAG AA.
class EventPalette {
  static Color accent(BuildContext context, {required bool birthday}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (birthday) {
      return dark ? const Color(0xFFFFCC80) : const Color(0xFF7C2D12);
    }
    return dark ? const Color(0xFFFFB2C8) : const Color(0xFF9D174D);
  }
}
