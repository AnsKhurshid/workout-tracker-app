import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../services/clock.dart';

/// Read/write access to the sync outbox.
///
/// Repositories call [enqueue] **inside the same transaction** as the change it
/// describes, so a change and its queue entry are always committed together.
/// The background sync engine (Phase 6) drains the queue; until then a
/// repository may push its own entries directly (see ProfileRepositoryImpl).
class Outbox {
  Outbox(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Queues [recordId] in [table] for upload. Re-queuing an entry that is
  /// already waiting just refreshes it (one entry per record).
  Future<void> enqueue({
    required String userId,
    required String table,
    required String recordId,
  }) async {
    final now = _clock.nowUtc();
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: userId,
            entityTable: table,
            recordId: recordId,
            enqueuedAt: now,
            nextAttemptAt: now,
          ),
          onConflict: DoUpdate(
            (_) => SyncOutboxCompanion(
              userId: Value(userId),
              enqueuedAt: Value(now),
              nextAttemptAt: Value(now),
              attempts: const Value(0),
              lastError: const Value(null),
              state: const Value('pending'),
            ),
            target: [_db.syncOutbox.entityTable, _db.syncOutbox.recordId],
          ),
        );
  }

  Future<OutboxEntry?> find(String table, String recordId) => (_db.select(
    _db.syncOutbox,
  )..where((o) => o.entityTable.equals(table) & o.recordId.equals(recordId))).getSingleOrNull();

  Future<void> remove(String table, String recordId) => (_db.delete(
    _db.syncOutbox,
  )..where((o) => o.entityTable.equals(table) & o.recordId.equals(recordId))).go();

  /// Records a failed push. Transient failures stay `pending` and are retried
  /// after an exponential backoff; permanent ones are marked `failed`.
  Future<void> recordFailure(
    String table,
    String recordId, {
    required String error,
    required bool permanent,
  }) async {
    final entry = await find(table, recordId);
    if (entry == null) return;
    final attempts = entry.attempts + 1;
    await (_db.update(_db.syncOutbox)..where((o) => o.id.equals(entry.id))).write(
      SyncOutboxCompanion(
        attempts: Value(attempts),
        lastError: Value(error),
        nextAttemptAt: Value(_clock.nowUtc().add(backoff(attempts))),
        state: Value(permanent ? 'failed' : 'pending'),
      ),
    );
  }

  /// 5 s, 10 s, 20 s ... capped at 10 minutes.
  static Duration backoff(int attempts) {
    final seconds = 5 * (1 << (attempts - 1).clamp(0, 10));
    return Duration(seconds: seconds.clamp(5, 600));
  }

  /// Number of entries waiting for [userId] (pending or failed).
  Stream<int> watchCount(String userId) {
    final count = _db.syncOutbox.id.count();
    final query = _db.selectOnly(_db.syncOutbox)
      ..addColumns([count])
      ..where(_db.syncOutbox.userId.equals(userId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}
