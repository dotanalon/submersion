import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v258: gas_switches.computer_id, the computer whose reading a
/// switch came from (issue #2582).
void main() {
  /// A v257 database whose gas_switches lacks the column: one switch to a
  /// computer's cylinder and one to a cylinder no computer owns.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 257');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, computer_id TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE gas_switches (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, timestamp INTEGER NOT NULL, '
        'tank_id TEXT NOT NULL, depth REAL, created_at INTEGER NOT NULL, '
        'hlc TEXT)',
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

  test('v258 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 258);
    expect(AppDatabase.migrationVersions.last, 258);
    expect(
      AppDatabase.migrationStepCount(257),
      1,
      reason: 'one rung above v257',
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v257 attributes each switch to its cylinder\'s computer',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final rows = await db
          .customSelect('SELECT id, computer_id FROM gas_switches ORDER BY id')
          .get();
      expect(
        [for (final r in rows) r.read<String?>('computer_id')],
        ['c1', null],
      );
    },
  );
}
