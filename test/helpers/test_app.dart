import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/app.dart';
import 'package:gym_tracker/core/config/env_config.dart';
import 'package:gym_tracker/core/database/app_database.dart';
import 'package:gym_tracker/core/logging/app_logger.dart';
import 'package:gym_tracker/core/providers.dart';
import 'package:gym_tracker/core/services/clock.dart';
import 'package:gym_tracker/features/authentication/presentation/auth_providers.dart';
import 'package:gym_tracker/features/profile/presentation/profile_providers.dart';

import 'fakes.dart';
import 'test_database.dart';

/// Everything a widget test may want to inspect after pumping the app.
class TestApp {
  TestApp({
    required this.auth,
    required this.db,
    required this.remote,
    required this.supabase,
    required this.logger,
  });

  final FakeAuthRepository auth;
  final AppDatabase db;
  final FakeProfileRemote remote;
  final FakeSupabaseService supabase;
  final AppLogger logger;
}

/// Pumps the real app with fakes for every external dependency: no network,
/// no Supabase credentials, in-memory database.
Future<TestApp> pumpTestApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  EnvConfig env = validEnv,
  FakeProfileRemote? remote,
  FakeSupabaseService? supabase,
}) async {
  // A tall phone-sized surface so most screens fit without scrolling.
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final app = TestApp(
    auth: auth ?? FakeAuthRepository(),
    db: newTestDatabase(),
    remote: remote ?? FakeProfileRemote(),
    supabase: supabase ?? FakeSupabaseService(),
    logger: AppLogger(minLevel: LogLevel.error),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLoggerProvider.overrideWithValue(app.logger),
        envConfigProvider.overrideWithValue(env),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 11, 2, 12))),
        appDatabaseProvider.overrideWithValue(app.db),
        supabaseServiceProvider.overrideWithValue(app.supabase),
        authRepositoryProvider.overrideWithValue(app.auth),
        profileRemoteDataSourceProvider.overrideWithValue(app.remote),
      ],
      child: const GymTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();

  addTearDown(() async {
    // Unmount first so providers and streams are disposed before the database closes.
    await tester.pumpWidget(const SizedBox.shrink());
    await app.db.close();
  });
  return app;
}
