import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The on-device SQLite database: the source of truth for everything the
/// user does (see ARCHITECTURE.md §6).
@DriftDatabase(tables: [Profiles, AppSettings, SyncOutbox, SyncCursors])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the app's database file. `drift_flutter` stores it in the
  /// application support directory and runs SQLite on a background isolate,
  /// so queries never block the UI thread.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: AppConstants.databaseName,
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );

  /// Bump when the schema changes and add a step in [migration].
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add one step per version, e.g.
      //   if (from < 2) { await m.createTable(exercises); }
      // Run `dart run drift_dev make-migrations` after changing the schema.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Forces the database to open (and migrate) now, so failures surface during
  /// app startup instead of on the first screen that reads data.
  Future<void> ensureOpen() async {
    await customSelect('SELECT 1').get();
  }
}
