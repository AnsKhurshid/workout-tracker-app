import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Builds the app's Material 3 themes.
///
/// Dark and light share one builder, so every component theme exists in both
/// and switching is only a `ThemeMode` change.
abstract final class AppTheme {
  static ThemeData dark() => _build(_darkScheme, AppTokens.dark);

  static ThemeData light() => _build(_lightScheme, AppTokens.light);

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.lime,
    onPrimary: AppPalette.darkBackground,
    primaryContainer: AppPalette.limeContainerDark,
    onPrimaryContainer: AppPalette.lime,
    secondary: AppPalette.darkOnSurfaceVariant,
    onSecondary: AppPalette.darkBackground,
    secondaryContainer: AppPalette.darkSurfaceHighest,
    onSecondaryContainer: AppPalette.darkOnSurface,
    tertiary: AppPalette.infoDark,
    onTertiary: AppPalette.darkBackground,
    error: AppPalette.errorDark,
    onError: AppPalette.darkBackground,
    errorContainer: Color(0xFF3B1414),
    onErrorContainer: Color(0xFFFFC9C9),
    surface: AppPalette.darkBackground,
    onSurface: AppPalette.darkOnSurface,
    onSurfaceVariant: AppPalette.darkOnSurfaceVariant,
    surfaceContainerLowest: AppPalette.darkSurfaceLowest,
    surfaceContainerLow: AppPalette.darkSurfaceLow,
    surfaceContainer: AppPalette.darkSurface,
    surfaceContainerHigh: AppPalette.darkSurfaceHigh,
    surfaceContainerHighest: AppPalette.darkSurfaceHighest,
    outline: AppPalette.darkOutline,
    outlineVariant: AppPalette.darkOutlineVariant,
    inverseSurface: AppPalette.darkOnSurface,
    onInverseSurface: AppPalette.darkBackground,
    inversePrimary: AppPalette.limeDeep,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.limeDeep,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.limeContainerLight,
    onPrimaryContainer: Color(0xFF1F3305),
    secondary: AppPalette.lightOnSurfaceVariant,
    onSecondary: Colors.white,
    secondaryContainer: AppPalette.lightSurfaceHighest,
    onSecondaryContainer: AppPalette.lightOnSurface,
    tertiary: AppPalette.infoLight,
    onTertiary: Colors.white,
    error: AppPalette.errorLight,
    onError: Colors.white,
    errorContainer: Color(0xFFFDE2E2),
    onErrorContainer: Color(0xFF5F1010),
    surface: AppPalette.lightBackground,
    onSurface: AppPalette.lightOnSurface,
    onSurfaceVariant: AppPalette.lightOnSurfaceVariant,
    surfaceContainerLowest: AppPalette.lightSurfaceLowest,
    surfaceContainerLow: AppPalette.lightSurfaceLow,
    surfaceContainer: AppPalette.lightSurface,
    surfaceContainerHigh: AppPalette.lightSurfaceHigh,
    surfaceContainerHighest: AppPalette.lightSurfaceHighest,
    outline: AppPalette.lightOutline,
    outlineVariant: AppPalette.lightOutlineVariant,
    inverseSurface: AppPalette.lightOnSurface,
    onInverseSurface: AppPalette.lightBackground,
    inversePrimary: AppPalette.lime,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme, AppTokens tokens) {
    final textTheme = AppTypography.textTheme(scheme.onSurface, scheme.onSurfaceVariant);
    final isDark = scheme.brightness == Brightness.dark;
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadii.mdAll);
    const buttonSize = Size.fromHeight(AppSizes.buttonHeight);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens],
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder(tokens.cardBorder),
        enabledBorder: inputBorder(tokens.cardBorder),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        disabledBorder: inputBorder(tokens.cardBorder.withValues(alpha: 0.5)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 3,
        helperMaxLines: 3,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.navigationBarHeight,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.18),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          textStyle: textTheme.labelLarge,
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.16),
          selectedForegroundColor: scheme.onSurface,
          side: BorderSide(color: tokens.cardBorder),
          shape: buttonShape,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: AppSpacing.sm,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      dividerTheme: DividerThemeData(color: tokens.cardBorder, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: isDark ? AppPalette.limeDeep : AppPalette.lime,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: tokens.cardBorder),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
      ),
    );
  }
}
