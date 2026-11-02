// Drift's `.check()` refers to the column getter inside its own definition;
// that is the documented Drift pattern, not real recursion.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

// Local SQLite tables (schema version 1).
//
// Mirrors of server tables keep the same column names as
// `supabase/migrations` so the sync layer can map rows one-to-one. Workout
// tables arrive in later phases as new schema versions.

/// Mirror of `public.profiles`. One row per user who has signed in on this
/// device; rows are isolated by `id` (the auth user id).
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().named('display_name').nullable()();

  /// `kg` or `lbs` (Postgres enum `weight_unit`).
  TextColumn get weightUnit => text()
      .named('weight_unit')
      .withDefault(const Constant('kg'))
      .check(weightUnit.isIn(const ['kg', 'lbs']))();
  IntColumn get defaultRestSeconds => integer()
      .named('default_rest_seconds')
      .withDefault(const Constant(90))
      .check(defaultRestSeconds.isBetweenValues(0, 3600))();
  BoolColumn get autoStartRestTimer =>
      boolean().named('auto_start_rest_timer').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  /// Last `server_updated_at` seen for this row; null if never synced.
  DateTimeColumn get serverUpdatedAt => dateTime().named('server_updated_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-level key/value settings (theme, etc.). Not synced.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Pending local changes waiting to be pushed to Supabase.
///
/// One row per (table, record). The row stores *which* record changed, not a
/// payload: the push always sends the record's current local state. Entries
/// are written in the same transaction as the change they describe.
@DataClassName('OutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get entityTable => text().named('entity_table')();
  TextColumn get recordId => text().named('record_id')();
  DateTimeColumn get enqueuedAt => dateTime().named('enqueued_at')();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().named('next_attempt_at')();
  TextColumn get lastError => text().named('last_error').nullable()();

  /// `pending` (will be retried) or `failed` (rejected by the server; needs
  /// attention, never silently dropped).
  TextColumn get state => text()
      .withDefault(const Constant('pending'))
      .check(state.isIn(const ['pending', 'failed']))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityTable, recordId},
  ];
}

/// Per-user, per-table pull cursor (the max `server_updated_at` received).
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  TextColumn get userId => text().named('user_id')();
  TextColumn get entityTable => text().named('entity_table')();
  DateTimeColumn get cursor => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, entityTable};
}
