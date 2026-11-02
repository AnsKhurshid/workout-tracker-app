import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gym_tracker/core/database/app_database.dart';

/// Fresh in-memory database. `closeStreamsSynchronously` avoids pending
/// timers at the end of widget tests.
AppDatabase newTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}
