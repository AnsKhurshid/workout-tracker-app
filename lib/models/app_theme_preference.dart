import 'package:flutter/material.dart';

/// The theme the user picked. Stored per device.
enum AppThemePreference {
  system('system', 'System'),
  dark('dark', 'Dark'),
  light('light', 'Light');

  const AppThemePreference(this.storageValue, this.label);

  final String storageValue;
  final String label;

  /// The app is dark-first.
  static const defaultValue = AppThemePreference.dark;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.light => ThemeMode.light,
  };

  static AppThemePreference fromStorage(String? value) => AppThemePreference.values.firstWhere(
    (p) => p.storageValue == value,
    orElse: () => defaultValue,
  );
}
