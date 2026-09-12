import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// v208: retires the per-metric Computer/Calculated source preference.
///
/// Every decompression metric on the dive profile is now the app's own
/// Buhlmann calculation, so the six `default_*_source` columns no longer steer
/// anything. `default_ceiling_source` had already been inert since #755/#761
/// (the ceiling line always renders the calculated curve), and #767 asked for
/// its column drop to ride along with the next `diver_settings` migration done
/// for another reason -- this is that migration. `use_dive_computer_cns_data` is the v42 ancestor of
/// `default_cns_source` and has been read by nothing since, so it goes too.
///
/// The drop must survive the `beforeOpen` backstops, which re-assert the
/// deco-stop and GTR settings columns unconditionally on every open. If either
/// helper keeps a branch for its source column it will silently re-add what
/// this rung dropped, which is what the second test here guards.
const _retiredColumns = <String>[
  'default_ndl_source',
  'default_ceiling_source',
  'default_tts_source',
  'default_cns_source',
  'default_deco_stop_source',
  'default_gtr_source',
  'use_dive_computer_cns_data',
];

NativeDatabase _dbAt207() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 207');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          default_ndl_source INTEGER NOT NULL DEFAULT 1,
          default_ceiling_source INTEGER NOT NULL DEFAULT 1,
          default_tts_source INTEGER NOT NULL DEFAULT 1,
          default_cns_source INTEGER NOT NULL DEFAULT 1,
          default_deco_stop_source INTEGER NOT NULL DEFAULT 1,
          default_gtr_source INTEGER NOT NULL DEFAULT 1,
          use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v208 drops every retired metric-source column', () async {
    final db = AppDatabase(_dbAt207());
    addTearDown(db.close);

    final names = await _columns(db, 'diver_settings');
    for (final column in _retiredColumns) {
      expect(
        names,
        isNot(contains(column)),
        reason: '$column should have been dropped by the v208 rung',
      );
    }

    // The row itself survives the table rebuild.
    final row = await db
        .customSelect('SELECT id FROM diver_settings')
        .getSingle();
    expect(row.read<String>('id'), 'settings');
  });

  test('v208 is a no-op on a database that never had the columns', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 207');
          rawDb.execute('''
            CREATE TABLE diver_settings (
              id TEXT NOT NULL PRIMARY KEY
            )
          ''');
          rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
        },
      ),
    );
    addTearDown(db.close);

    final names = await _columns(db, 'diver_settings');
    expect(names, contains('id'));
    for (final column in _retiredColumns) {
      expect(names, isNot(contains(column)));
    }
  });

  test('v208 is the current schema version and is in the ladder', () {
    // Exact-latest tripwire, inherited from the v207 test. The next migration
    // to land relaxes this one and takes it over.
    expect(AppDatabase.currentSchemaVersion, 208);
    expect(AppDatabase.migrationVersions, contains(208));
  });

  test(
    'a freshly created database carries none of the retired columns',
    () async {
      // Tripwire: catches a backstop helper that still re-asserts one of the
      // source columns, and catches the table definition drifting back.
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);

      final names = await _columns(db, 'diver_settings');
      for (final column in _retiredColumns) {
        expect(
          names,
          isNot(contains(column)),
          reason: '$column is retired and must not be re-created',
        );
      }
    },
  );
}
