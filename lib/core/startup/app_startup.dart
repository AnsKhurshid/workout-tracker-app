import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../errors/error_mapper.dart';
import '../providers.dart';

/// Everything that must succeed before the main app is shown:
///   1. build-time configuration is present;
///   2. the local database opens and migrates;
///   3. Supabase is initialised (restores a saved session; works offline).
///
/// Runs while a splash screen is visible. Failures are mapped to an
/// [AppFailure] and shown with a retry button; nothing is deleted.
final appStartupProvider = FutureProvider<void>((ref) async {
  final logger = ref.read(appLoggerProvider);
  try {
    final env = ref.read(envConfigProvider)..validate();

    final db = ref.read(appDatabaseProvider);
    try {
      await db.ensureOpen();
    } catch (e, st) {
      logger.error('Local database failed to open', e, st);
      throw StorageFailure(debugMessage: 'Database open failed: $e', cause: e);
    }

    await ref.read(supabaseServiceProvider).initialize(env);
    logger.info('App startup complete');
  } catch (e, st) {
    final failure = mapError(e);
    if (failure is! StorageFailure) {
      logger.error('App startup failed', e, st);
    }
    throw failure;
  }
}, retry: (_, _) => null);
