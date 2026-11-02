import 'package:drift/drift.dart';

import '../../models/app_theme_preference.dart';
import '../database/app_database.dart';
import '../services/clock.dart';

/// Device-level preferences that are not tied to an account (they apply on
/// the welcome screen too, before anyone signs in).
abstract interface class AppSettingsRepository {
  Stream<AppThemePreference> watchThemePreference();
  Future<AppThemePreference> getThemePreference();
  Future<void> setThemePreference(AppThemePreference preference);
}

class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const themeKey = 'theme_mode';

  SimpleSelectStatement<$AppSettingsTable, AppSettingRow> _byKey(String key) =>
      _db.select(_db.appSettings)..where((s) => s.key.equals(key));

  @override
  Stream<AppThemePreference> watchThemePreference() =>
      _byKey(themeKey).watchSingleOrNull().map((row) => AppThemePreference.fromStorage(row?.value));

  @override
  Future<AppThemePreference> getThemePreference() async =>
      AppThemePreference.fromStorage((await _byKey(themeKey).getSingleOrNull())?.value);

  @override
  Future<void> setThemePreference(AppThemePreference preference) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: themeKey,
          value: preference.storageValue,
          updatedAt: _clock.nowUtc(),
        ),
      );
}
