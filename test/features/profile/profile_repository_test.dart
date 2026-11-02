import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/database/app_database.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/core/logging/app_logger.dart';
import 'package:gym_tracker/core/services/clock.dart';
import 'package:gym_tracker/core/sync/outbox.dart';
import 'package:gym_tracker/features/profile/data/profile_repository_impl.dart';
import 'package:gym_tracker/models/weight_unit.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeProfileRemote remote;
  late ProfileRepositoryImpl repo;

  ProfileRepositoryImpl build(AppDatabase database) => ProfileRepositoryImpl(
    db: database,
    outbox: Outbox(database, clock),
    remote: remote,
    clock: clock,
    logger: AppLogger(minLevel: LogLevel.error),
  );

  setUp(() {
    db = newTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 11, 2, 12));
    remote = FakeProfileRemote();
    repo = build(db);
  });
  tearDown(() => db.close());

  Future<int> outboxCount() async => (await db.select(db.syncOutbox).get()).length;

  test('loadProfile copies the server profile into the local database', () async {
    remote.rows[testUser.id] = remoteProfile(
      displayName: 'Sam R',
      weightUnit: 'lbs',
      updatedAt: DateTime.utc(2026, 10, 1),
    );

    await repo.loadProfile(testUser);

    final profile = await repo.watchProfile(testUser.id).first;
    expect(profile!.displayName, 'Sam R');
    expect(profile.weightUnit, WeightUnit.lbs);
    expect(await outboxCount(), 0);
  });

  test('loadProfile offline creates a local placeholder without queuing it', () async {
    remote.fetchError = const SocketException('offline');

    await repo.loadProfile(testUser);

    final profile = await repo.watchProfile(testUser.id).first;
    expect(profile!.displayName, 'Sam'); // from sign-up metadata
    expect(profile.weightUnit, WeightUnit.kg);
    expect(await outboxCount(), 0, reason: 'placeholder must never overwrite the server row');

    // Once online, the server copy replaces the placeholder.
    remote
      ..fetchError = null
      ..rows[testUser.id] = remoteProfile(weightUnit: 'lbs', updatedAt: DateTime.utc(2026, 10, 1));
    await repo.loadProfile(testUser);
    expect((await repo.watchProfile(testUser.id).first)!.weightUnit, WeightUnit.lbs);
  });

  test('changing the weight unit saves locally, queues and uploads it', () async {
    remote.rows[testUser.id] = remoteProfile(updatedAt: DateTime.utc(2026, 10, 1));
    await repo.loadProfile(testUser);

    await repo.updateWeightUnit(testUser.id, WeightUnit.lbs);

    expect((await repo.watchProfile(testUser.id).first)!.weightUnit, WeightUnit.lbs);
    expect(remote.rows[testUser.id]!.weightUnit, 'lbs');
    expect(remote.rows[testUser.id]!.updatedAt, clock.nowUtc());
    expect(await outboxCount(), 0, reason: 'uploaded, so nothing is pending');
  });

  test('offline change stays queued and is uploaded later', () async {
    remote.rows[testUser.id] = remoteProfile(updatedAt: DateTime.utc(2026, 10, 1));
    await repo.loadProfile(testUser);
    remote.upsertError = const SocketException('offline');

    await repo.updateWeightUnit(testUser.id, WeightUnit.lbs);

    expect((await repo.watchProfile(testUser.id).first)!.weightUnit, WeightUnit.lbs);
    expect(await repo.watchHasPendingChanges(testUser.id).first, isTrue);
    final entry = (await db.select(db.syncOutbox).getSingle());
    expect(entry.state, 'pending');
    expect(entry.attempts, 1);

    // Not retried before the backoff has passed.
    remote.upsertError = null;
    await repo.pushPendingChanges(testUser.id);
    expect(remote.upserts, 0);

    clock.advance(const Duration(seconds: 6));
    await repo.pushPendingChanges(testUser.id);
    expect(remote.rows[testUser.id]!.weightUnit, 'lbs');
    expect(await repo.watchHasPendingChanges(testUser.id).first, isFalse);
  });

  test('a newer local change is not overwritten by an older server copy', () async {
    remote.rows[testUser.id] = remoteProfile(updatedAt: DateTime.utc(2026, 10, 1));
    await repo.loadProfile(testUser);
    remote.upsertError = const SocketException('offline');
    await repo.updateWeightUnit(testUser.id, WeightUnit.lbs);

    // Refresh brings the (older) server row back while the change is queued.
    await repo.loadProfile(testUser);

    expect((await repo.watchProfile(testUser.id).first)!.weightUnit, WeightUnit.lbs);
    expect(await outboxCount(), 1);
  });

  test('a newer server copy replaces local data and clears the stale entry', () async {
    remote.rows[testUser.id] = remoteProfile(updatedAt: DateTime.utc(2026, 10, 1));
    await repo.loadProfile(testUser);
    remote.upsertError = const SocketException('offline');
    await repo.updateWeightUnit(testUser.id, WeightUnit.lbs);

    // Another device changed the profile later.
    remote
      ..upsertError = null
      ..rows[testUser.id] = remoteProfile(
        displayName: 'Other device',
        updatedAt: clock.nowUtc().add(const Duration(hours: 1)),
      );
    await repo.loadProfile(testUser);

    final profile = await repo.watchProfile(testUser.id).first;
    expect(profile!.displayName, 'Other device');
    expect(profile.weightUnit, WeightUnit.kg);
    expect(await outboxCount(), 0);
  });

  test('display name is validated before saving', () async {
    await repo.loadProfile(testUser);
    expect(() => repo.updateDisplayName(testUser.id, '  '), throwsA(isA<ValidationFailure>()));
    await repo.updateDisplayName(testUser.id, '  Samira ');
    expect((await repo.watchProfile(testUser.id).first)!.displayName, 'Samira');
  });

  test('profiles are isolated per user', () async {
    remote.fetchError = const SocketException('offline');
    await repo.loadProfile(testUser);
    expect(await repo.watchProfile('someone-else').first, isNull);
  });

  test('weight unit preference persists across app restarts', () async {
    final dir = await Directory.systemTemp.createTemp('gym_tracker_profile');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    remote.fetchError = const SocketException('offline');
    remote.upsertError = const SocketException('offline');

    final first = AppDatabase(NativeDatabase(file));
    final firstRepo = build(first);
    await firstRepo.loadProfile(testUser);
    await firstRepo.updateWeightUnit(testUser.id, WeightUnit.lbs);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final secondRepo = build(second);
    expect((await secondRepo.watchProfile(testUser.id).first)!.weightUnit, WeightUnit.lbs);
    expect(await secondRepo.watchHasPendingChanges(testUser.id).first, isTrue);
  });
}
