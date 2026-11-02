import 'package:flutter/material.dart';

/// Type scale built on Inter (bundled, SIL OFL; see assets/fonts).
///
/// Sizes never go below 12 so workout data stays readable at arm's length.
abstract final class AppTypography {
  static const fontFamily = 'Inter';

  /// Tabular figures keep columns of weights and reps aligned.
  static const tabularFigures = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    TextStyle style(
      double size,
      FontWeight weight,
      double height, {
      double spacing = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? onSurface,
    );

    return TextTheme(
      displayLarge: style(48, FontWeight.w700, 1.1, spacing: -1),
      displayMedium: style(40, FontWeight.w700, 1.1, spacing: -0.8),
      displaySmall: style(34, FontWeight.w700, 1.15, spacing: -0.6),
      headlineLarge: style(30, FontWeight.w700, 1.2, spacing: -0.5),
      headlineMedium: style(26, FontWeight.w600, 1.25, spacing: -0.4),
      headlineSmall: style(22, FontWeight.w600, 1.3, spacing: -0.2),
      titleLarge: style(20, FontWeight.w600, 1.3, spacing: -0.1),
      titleMedium: style(16, FontWeight.w600, 1.4),
      titleSmall: style(14, FontWeight.w600, 1.4),
      bodyLarge: style(16, FontWeight.w400, 1.5),
      bodyMedium: style(14, FontWeight.w400, 1.45),
      bodySmall: style(12, FontWeight.w400, 1.4, color: onSurfaceVariant),
      labelLarge: style(15, FontWeight.w600, 1.3, spacing: 0.1),
      labelMedium: style(13, FontWeight.w500, 1.3, spacing: 0.1),
      labelSmall: style(12, FontWeight.w500, 1.3, spacing: 0.2),
    );
  }
}
