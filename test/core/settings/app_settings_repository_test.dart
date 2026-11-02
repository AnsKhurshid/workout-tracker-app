import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/services/clock.dart';
import 'package:gym_tracker/core/settings/app_settings_repository.dart';
import 'package:gym_tracker/models/app_theme_preference.dart';

import '../../helpers/test_database.dart';

void main() {
  test('theme preference defaults to dark and persists changes', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final repo = DriftAppSettingsRepository(db, FixedClock(DateTime.utc(2026)));

    expect(await repo.getThemePreference(), AppThemePreference.dark);

    final emitted = <AppThemePreference>[];
    final sub = repo.watchThemePreference().listen(emitted.add);
    addTearDown(sub.cancel);

    await repo.setThemePreference(AppThemePreference.light);
    expect(await repo.getThemePreference(), AppThemePreference.light);
    await repo.setThemePreference(AppThemePreference.system);
    expect(await repo.getThemePreference(), AppThemePreference.system);

    await pumpEventQueue();
    expect(emitted.first, AppThemePreference.dark);
    expect(emitted.last, AppThemePreference.system);
  });
}
