import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/database/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  test('opens, creates the schema and enables foreign keys', () async {
    final db = newTestDatabase();
    addTearDown(db.close);

    await db.ensureOpen();

    expect(db.schemaVersion, 1);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row.read<String>('name'))
        .get();
    expect(tables, containsAll(['profiles', 'app_settings', 'sync_outbox', 'sync_cursors']));

    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
  });

  test('enforces CHECK constraints mirrored from Postgres', () async {
    final db = newTestDatabase();
    addTearDown(db.close);
    final now = DateTime.utc(2026);

    expect(
      () => db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: 'u1',
              weightUnit: const Value('stone'),
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('data survives closing and reopening a database file', () async {
    final dir = await Directory.systemTemp.createTemp('gym_tracker_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.sqlite');
    final now = DateTime.utc(2026, 3, 4, 5, 6, 7, 890);

    final first = AppDatabase(NativeDatabase(file));
    await first
        .into(first.profiles)
        .insert(ProfilesCompanion.insert(id: 'u1', createdAt: now, updatedAt: now));
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final row = await second.select(second.profiles).getSingle();
    expect(row.id, 'u1');
    // Text storage keeps millisecond precision.
    expect(row.updatedAt.toUtc(), now);
  });
}
