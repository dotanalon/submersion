import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v258: gas_switches.computer_id, the computer whose reading a
/// switch came from (issue #2582).
void main() {
  /// A database at [version] holding one switch to a computer's cylinder and
  /// one to a cylinder no computer owns; [withColumn] gives gas_switches the
  /// v258 column already, both switches unattributed.
  NativeDatabase setupDb({int version = 257, bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          // The parent table the column references; beforeOpen runs with
          // foreign keys enforced.
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1')");
          rawDb.execute(
            'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
            'dive_id TEXT NOT NULL, computer_id TEXT)',
          );
          rawDb.execute(
            'CREATE TABLE gas_switches (id TEXT NOT NULL PRIMARY KEY, '
            'dive_id TEXT NOT NULL, timestamp INTEGER NOT NULL, '
            'tank_id TEXT NOT NULL, depth REAL, created_at INTEGER NOT NULL, '
            'hlc TEXT${withColumn ? ', computer_id TEXT' : ''})',
          );
          rawDb.execute(
            "INSERT INTO dive_tanks (id, dive_id, computer_id) VALUES "
            "('t1', 'd1', 'c1'), ('t2', 'd1', NULL)",
          );
          rawDb.execute(
            'INSERT INTO gas_switches '
            '(id, dive_id, timestamp, tank_id, created_at) VALUES '
            "('s1', 'd1', 0, 't1', 1), ('s2', 'd1', 60, 't2', 1)",
          );
        },
      );

  Future<List<String?>> switchComputers(AppDatabase db) async => [
    for (final r
        in await db
            .customSelect('SELECT computer_id FROM gas_switches ORDER BY id')
            .get())
      r.read<String?>('computer_id'),
  ];

  test('v258 is at or below the current schema version and in the ladder', () {
    // Sits below v259 (dive_tanks.usage_duration, #1496), which main
    // shipped first and which owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(258));
    expect(AppDatabase.migrationVersions, containsAll([257, 258, 259]));
    expect(
      AppDatabase.migrationStepCount(257),
      AppDatabase.migrationStepCount(258) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v257 attributes each switch to its cylinder\'s computer',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      expect(await switchComputers(db), ['c1', null]);
    },
  );

  test('a database already at v259 without the column gains it, backfill '
      'included, via beforeOpen', () async {
    final db = AppDatabase(setupDb(version: 259));
    addTearDown(db.close);
    expect(await switchComputers(db), ['c1', null]);
  });

  test('a database that has the column keeps an unattributed switch '
      'unattributed: it is one the diver entered', () async {
    final db = AppDatabase(setupDb(version: 259, withColumn: true));
    addTearDown(db.close);
    expect(await switchComputers(db), [null, null]);
  });
}
