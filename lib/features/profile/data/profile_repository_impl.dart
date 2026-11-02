import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/services/clock.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_tables.dart';
import '../../../core/utils/validators.dart';
import '../../../models/auth_user.dart';
import '../../../models/user_profile.dart';
import '../../../models/weight_unit.dart';
import '../domain/profile_remote_data_source.dart';
import '../domain/profile_repository.dart';

/// Local-first profile repository.
///
/// * Writes update the local row and enqueue an outbox entry in one
///   transaction, then try to push immediately. If the push fails the entry
///   stays queued (with backoff) and is retried later; the change is never lost.
/// * Reads always come from the local database.
/// * The general sync engine (Phase 6) will take over pushing; this class
///   then only writes locally.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required this._db,
    required this._outbox,
    required this._remote,
    required this._clock,
    required this._logger,
  });

  final AppDatabase _db;
  final Outbox _outbox;
  final ProfileRemoteDataSource _remote;
  final Clock _clock;
  final AppLogger _logger;

  static const _table = SyncTables.profiles;

  /// Timestamp for rows created locally from auth metadata. Any server row
  /// is newer, so it always wins over this placeholder.
  static final _placeholderTime = DateTime.utc(1970);

  SimpleSelectStatement<$ProfilesTable, ProfileRow> _byId(String id) =>
      _db.select(_db.profiles)..where((p) => p.id.equals(id));

  static UserProfile _toDomain(ProfileRow row) => UserProfile(
    id: row.id,
    displayName: row.displayName,
    weightUnit: WeightUnit.fromDb(row.weightUnit),
    defaultRestSeconds: row.defaultRestSeconds,
    autoStartRestTimer: row.autoStartRestTimer,
    updatedAt: row.updatedAt,
  );

  @override
  Stream<UserProfile?> watchProfile(String userId) =>
      _byId(userId).watchSingleOrNull().map((row) => row == null ? null : _toDomain(row));

  @override
  Stream<bool> watchHasPendingChanges(String userId) =>
      _outbox.watchCount(userId).map((count) => count > 0);

  @override
  Future<void> loadProfile(AuthUser user) async {
    await _storage(() async {
      final existing = await _byId(user.id).getSingleOrNull();
      if (existing == null) {
        // Placeholder so the UI has something to show offline. Not queued:
        // it is not a user change and must never overwrite the server row.
        await _db
            .into(_db.profiles)
            .insert(
              ProfilesCompanion.insert(
                id: user.id,
                displayName: Value(user.displayName),
                createdAt: _placeholderTime,
                updatedAt: _placeholderTime,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    try {
      final remote = await _remote.fetch(user.id);
      if (remote != null) await _mergeRemote(remote);
    } catch (e, st) {
      // Offline or server error: keep using the local copy.
      _logger.warning('Profile refresh failed; using local copy', e, st);
    }
    await pushPendingChanges(user.id);
  }

  /// Applies a server row unless a newer local change is waiting to upload.
  Future<void> _mergeRemote(RemoteProfile remote) => _storage(
    () => _db.transaction(() async {
      final local = await _byId(remote.id).getSingleOrNull();
      final pending = await _outbox.find(_table, remote.id);
      if (local != null && pending != null && local.updatedAt.isAfter(remote.updatedAt)) {
        return; // local edit is newer; it will be pushed
      }
      await _db
          .into(_db.profiles)
          .insertOnConflictUpdate(
            ProfilesCompanion.insert(
              id: remote.id,
              displayName: Value(remote.displayName),
              weightUnit: Value(remote.weightUnit),
              defaultRestSeconds: Value(remote.defaultRestSeconds),
              autoStartRestTimer: Value(remote.autoStartRestTimer),
              createdAt: remote.createdAt,
              updatedAt: remote.updatedAt,
              deletedAt: Value(remote.deletedAt),
              serverUpdatedAt: Value(remote.serverUpdatedAt),
            ),
          );
      if (pending != null) await _outbox.remove(_table, remote.id);
    }),
  );

  @override
  Future<void> updateWeightUnit(String userId, WeightUnit unit) =>
      _update(userId, ProfilesCompanion(weightUnit: Value(unit.dbValue)));

  @override
  Future<void> updateDisplayName(String userId, String displayName) {
    final error = Validators.displayName(displayName);
    if (error != null) throw ValidationFailure(error);
    return _update(userId, ProfilesCompanion(displayName: Value(displayName.trim())));
  }

  Future<void> _update(String userId, ProfilesCompanion changes) async {
    await _storage(
      () => _db.transaction(() async {
        final now = _clock.nowUtc();
        final updated = await (_db.update(
          _db.profiles,
        )..where((p) => p.id.equals(userId))).write(changes.copyWith(updatedAt: Value(now)));
        if (updated == 0) {
          throw const StorageFailure(debugMessage: 'No local profile for user');
        }
        await _outbox.enqueue(userId: userId, table: _table, recordId: userId);
      }),
    );
    await pushPendingChanges(userId);
  }

  @override
  Future<void> pushPendingChanges(String userId) async {
    final entry = await _outbox.find(_table, userId);
    if (entry == null || entry.state == 'failed') return;
    if (entry.nextAttemptAt.isAfter(_clock.nowUtc())) return;

    final row = await _byId(userId).getSingleOrNull();
    if (row == null) return;
    final pushedVersion = row.updatedAt;
    try {
      await _remote.upsert(
        RemoteProfile(
          id: row.id,
          displayName: row.displayName,
          weightUnit: row.weightUnit,
          defaultRestSeconds: row.defaultRestSeconds,
          autoStartRestTimer: row.autoStartRestTimer,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
        ),
      );
      // Remove the entry only if no newer edit happened during the push.
      await _db.transaction(() async {
        final current = await _byId(userId).getSingleOrNull();
        if (current != null && current.updatedAt == pushedVersion) {
          await _outbox.remove(_table, userId);
        }
      });
      _logger.debug('Profile change uploaded');
    } catch (e, st) {
      final failure = mapError(e);
      final permanent =
          failure is! NetworkFailure &&
          !(failure is AuthFailure && failure.kind == AuthFailureKind.sessionExpired);
      _logger.warning('Profile upload failed (${permanent ? 'permanent' : 'will retry'})', e, st);
      await _outbox.recordFailure(
        _table,
        userId,
        error: failure.debugMessage ?? failure.userMessage,
        permanent: permanent,
      );
    }
  }

  Future<T> _storage<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      _logger.error('Profile storage error', e, st);
      throw StorageFailure(debugMessage: e.toString(), cause: e);
    }
  }
}
