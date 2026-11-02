import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Design tokens that Material's [ColorScheme] has no slot for.
///
/// Read with `context.tokens` (see `theme_extensions.dart`).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.info,
    required this.cardBorder,
    required this.mutedText,
    required this.skeleton,
  });

  /// Completed sets, saved states.
  final Color success;
  final Color onSuccess;

  /// Warm-up sets, pending sync, cautions.
  final Color warning;
  final Color info;

  /// Subtle 1px border on cards and inputs.
  final Color cardBorder;
  final Color mutedText;
  final Color skeleton;

  static const dark = AppTokens(
    success: AppPalette.lime,
    onSuccess: AppPalette.darkBackground,
    warning: AppPalette.warningDark,
    info: AppPalette.infoDark,
    cardBorder: AppPalette.darkOutlineVariant,
    mutedText: AppPalette.darkOnSurfaceVariant,
    skeleton: AppPalette.darkSurfaceHighest,
  );

  static const light = AppTokens(
    success: AppPalette.limeDeep,
    onSuccess: Colors.white,
    warning: AppPalette.warningLight,
    info: AppPalette.infoLight,
    cardBorder: AppPalette.lightOutlineVariant,
    mutedText: AppPalette.lightOnSurfaceVariant,
    skeleton: AppPalette.lightSurfaceHighest,
  );

  @override
  AppTokens copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? info,
    Color? cardBorder,
    Color? mutedText,
    Color? skeleton,
  }) => AppTokens(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    cardBorder: cardBorder ?? this.cardBorder,
    mutedText: mutedText ?? this.mutedText,
    skeleton: skeleton ?? this.skeleton,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
    );
  }
}
