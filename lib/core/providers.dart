import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_theme_preference.dart';
import 'config/env_config.dart';
import 'database/app_database.dart';
import 'logging/app_logger.dart';
import 'services/clock.dart';
import 'services/id_generator.dart';
import 'services/supabase_service.dart';
import 'settings/app_settings_repository.dart';
import 'sync/outbox.dart';

// Application-level dependencies. Tests override these with fakes
// (in-memory database, fake auth, fixed clock).

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

final envConfigProvider = Provider<EnvConfig>((ref) => EnvConfig.fromEnvironment());

final clockProvider = Provider<Clock>((ref) => const Clock());

final idGeneratorProvider = Provider<IdGenerator>((ref) => const IdGenerator());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => DefaultSupabaseService(ref.watch(appLoggerProvider)),
);

final outboxProvider = Provider<Outbox>(
  (ref) => Outbox(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => DriftAppSettingsRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

/// The theme the user picked; dark until the stored value has loaded.
final themePreferenceProvider = StreamProvider<AppThemePreference>(
  (ref) => ref.watch(appSettingsRepositoryProvider).watchThemePreference(),
);
