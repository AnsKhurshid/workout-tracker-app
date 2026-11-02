import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_theme.dart';
import 'package:gym_tracker/core/theme/app_tokens.dart';
import 'package:gym_tracker/models/app_theme_preference.dart';

void main() {
  for (final (name, theme, brightness) in [
    ('dark', AppTheme.dark(), Brightness.dark),
    ('light', AppTheme.light(), Brightness.light),
  ]) {
    group('$name theme', () {
      test('is Material 3 with the expected brightness', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, brightness);
      });

      test('provides design tokens', () {
        expect(theme.extension<AppTokens>(), isNotNull);
      });

      test('uses the bundled font and readable minimum text size', () {
        final styles = [
          theme.textTheme.bodySmall,
          theme.textTheme.labelSmall,
          theme.textTheme.bodyMedium,
          theme.textTheme.titleLarge,
        ];
        for (final style in styles) {
          expect(style!.fontFamily, 'Inter');
          expect(style.fontSize, greaterThanOrEqualTo(12));
        }
      });

      test('configures component themes', () {
        expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.navigationBarTheme.height, isNotNull);
        expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.filledButtonTheme.style, isNotNull);
      });
    });
  }

  test('primary text has sufficient contrast with the background', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(7));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      expect(_contrast(scheme.onSurfaceVariant, scheme.surface), greaterThan(4.5));
    }
  });

  test('theme preference defaults to dark and maps to ThemeMode', () {
    expect(AppThemePreference.defaultValue, AppThemePreference.dark);
    expect(AppThemePreference.fromStorage(null), AppThemePreference.dark);
    expect(AppThemePreference.fromStorage('light').themeMode, ThemeMode.light);
    expect(AppThemePreference.fromStorage('system').themeMode, ThemeMode.system);
    expect(AppThemePreference.fromStorage('garbage'), AppThemePreference.dark);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
