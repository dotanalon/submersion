import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v208 is the current schema version and is in the ladder', () {
    // Renumbered again: trip grouping (204) and the gear-junction updated_at
    // (207) landed on main while this branch was open, and 205 and 206 are
    // claimed by the condition-intelligence branches.
    expect(AppDatabase.currentSchemaVersion, 208);
    expect(AppDatabase.migrationVersions, contains(208));
  });

  test(
    'a fresh database has the dive_plans stop_minimums_json column',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_plans')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('stop_minimums_json'));

      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'stop_minimums_json',
      );
      // Nullable, additive: an existing plan reads back with no minimums set.
      expect(column.read<int>('notnull'), 0);
    },
  );

  test(
    'a database stranded before v201 gains the column via beforeOpen',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_plans (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            gf_low INTEGER NOT NULL,
            gf_high INTEGER NOT NULL,
            ascent_rate REAL NOT NULL DEFAULT 9.0,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('dive_plans')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('stop_minimums_json'));
    },
  );

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
