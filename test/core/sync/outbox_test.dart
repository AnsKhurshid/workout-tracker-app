import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/database/app_database.dart';
import 'package:gym_tracker/core/services/clock.dart';
import 'package:gym_tracker/core/sync/outbox.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late Outbox outbox;

  setUp(() {
    db = newTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 11, 2, 12));
    outbox = Outbox(db, clock);
  });
  tearDown(() => db.close());

  test('enqueuing the same record twice keeps one entry and refreshes it', () async {
    await outbox.enqueue(userId: 'u1', table: 'profiles', recordId: 'u1');
    await outbox.recordFailure('profiles', 'u1', error: 'offline', permanent: false);
    clock.advance(const Duration(minutes: 1));
    await outbox.enqueue(userId: 'u1', table: 'profiles', recordId: 'u1');

    final entries = await db.select(db.syncOutbox).get();
    expect(entries, hasLength(1));
    expect(entries.single.attempts, 0);
    expect(entries.single.lastError, isNull);
    expect(entries.single.enqueuedAt, clock.nowUtc());
  });

  test('transient failures back off; permanent failures are kept as failed', () async {
    await outbox.enqueue(userId: 'u1', table: 'profiles', recordId: 'u1');
    await outbox.recordFailure('profiles', 'u1', error: 'offline', permanent: false);
    var entry = (await outbox.find('profiles', 'u1'))!;
    expect(entry.state, 'pending');
    expect(entry.attempts, 1);
    expect(entry.nextAttemptAt, clock.nowUtc().add(const Duration(seconds: 5)));

    await outbox.recordFailure('profiles', 'u1', error: 'rejected', permanent: true);
    entry = (await outbox.find('profiles', 'u1'))!;
    expect(entry.state, 'failed');
    expect(entry.lastError, 'rejected');
  });

  test('backoff doubles and is capped at 10 minutes', () {
    expect(Outbox.backoff(1), const Duration(seconds: 5));
    expect(Outbox.backoff(2), const Duration(seconds: 10));
    expect(Outbox.backoff(3), const Duration(seconds: 20));
    expect(Outbox.backoff(20), const Duration(minutes: 10));
  });

  test('pending count is per user', () async {
    await outbox.enqueue(userId: 'u1', table: 'profiles', recordId: 'u1');
    await outbox.enqueue(userId: 'u2', table: 'profiles', recordId: 'u2');
    expect(await outbox.watchCount('u1').first, 1);
    await outbox.remove('profiles', 'u1');
    expect(await outbox.watchCount('u1').first, 0);
    expect(await outbox.watchCount('u2').first, 1);
  });
}
