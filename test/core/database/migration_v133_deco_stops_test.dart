import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// Minimal pre-v133 diver_settings shape: enough columns to insert a row,
/// deliberately without the two deco stop band columns.
const _preV133DiverSettings = '''
  CREATE TABLE diver_settings (
    id TEXT NOT NULL PRIMARY KEY,
    diver_id TEXT NOT NULL,
    show_ceiling_on_profile INTEGER NOT NULL DEFAULT 1,
    default_ceiling_source INTEGER NOT NULL DEFAULT 1
  )
''';

const _insertLegacyRow =
    "INSERT INTO diver_settings "
    "(id, diver_id, show_ceiling_on_profile, default_ceiling_source) "
    "VALUES ('s1', 'd1', 0, 0)";

void main() {
  group('fresh install (onCreate)', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('diver_settings has the deco stop band columns', () async {
      final rows = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final cols = [for (final r in rows) r.read<String>('name')];
      expect(cols, contains('show_deco_stops_on_profile'));
      // default_deco_stop_source is added by this rung and dropped again at
      // v208, so a current-schema database must not carry it.
      expect(cols, isNot(contains('default_deco_stop_source')));
    });

    test('the deco stop band column defaults to visible', () async {
      final rows = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final byName = {
        for (final r in rows)
          r.read<String>('name'): r.read<String?>('dflt_value'),
      };
      expect(byName['show_deco_stops_on_profile'], '1');
    });
  });

  group('upgrade (onUpgrade)', () {
    test('v133 adds both columns to an existing database, preserving rows and '
        'applying the defaults to legacy rows', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 132');
          rawDb.execute(_preV133DiverSettings);
          rawDb.execute(_insertLegacyRow);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('show_deco_stops_on_profile'));
      // Added here, dropped again at v208 further up the same ladder.
      expect(names, isNot(contains('default_deco_stop_source')));
      expect(names, isNot(contains('default_ceiling_source')));

      final row = await db
          .customSelect(
            'SELECT show_ceiling_on_profile, show_deco_stops_on_profile '
            "FROM diver_settings WHERE id = 's1'",
          )
          .getSingle();

      // The diver's existing ceiling visibility survives untouched.
      expect(row.data['show_ceiling_on_profile'], 0);
      // The new non-nullable column takes its default on the legacy row.
      expect(row.data['show_deco_stops_on_profile'], 1);
    });

    test(
      'the migration is idempotent when the columns already exist',
      () async {
        // Exercises the PRAGMA guard branch: no duplicate ALTER, no thrown
        // "duplicate column name" error, and existing values are not reset.
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 132');
            rawDb.execute('''
            CREATE TABLE diver_settings (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL,
              show_ceiling_on_profile INTEGER NOT NULL DEFAULT 1,
              default_ceiling_source INTEGER NOT NULL DEFAULT 1,
              show_deco_stops_on_profile INTEGER NOT NULL DEFAULT 1,
              default_deco_stop_source INTEGER NOT NULL DEFAULT 1
            )
          ''');
            rawDb.execute(
              'INSERT INTO diver_settings (id, diver_id, '
              'show_deco_stops_on_profile, default_deco_stop_source) '
              "VALUES ('s1', 'd1', 0, 0)",
            );
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        final cols = await db
            .customSelect("PRAGMA table_info('diver_settings')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toList();
        expect(
          names.where((n) => n == 'show_deco_stops_on_profile').length,
          1,
          reason: 'show_deco_stops_on_profile should exist exactly once',
        );
        expect(
          names.where((n) => n == 'default_deco_stop_source').length,
          0,
          reason: 'v208 drops the source column further up the same ladder',
        );

        final row = await db
            .customSelect(
              'SELECT show_deco_stops_on_profile '
              "FROM diver_settings WHERE id = 's1'",
            )
            .getSingle();
        // The diver's own value survives both the v133 guard and the v208
        // table rebuild.
        expect(row.data['show_deco_stops_on_profile'], 0);
      },
    );
  });

  group('beforeOpen backstop', () {
    test('heals a database already stamped at currentSchemaVersion that is '
        'missing the deco stop columns', () async {
      // The parallel-branch collision case: another branch shipped the same
      // version number, so onUpgrade never runs for this database.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute(_preV133DiverSettings);
          rawDb.execute(_insertLegacyRow);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(
        names,
        contains('show_deco_stops_on_profile'),
        reason: 'the beforeOpen backstop must add the column',
      );
      // Tripwire: the backstop runs unconditionally on every open, so if it
      // still re-asserted the source column it would silently undo the v208
      // drop for every user.
      expect(names, isNot(contains('default_deco_stop_source')));
    });
  });

  test('v133 deco-stops migration stays in the schema ladder', () {
    // Relaxed from an exact-latest tripwire: v134 (media compressed rendition
    // columns) landed on top of v133, so the exact-latest assertion now lives
    // in media_compressed_columns_migration_test.dart.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(133));
    expect(AppDatabase.migrationVersions, contains(133));
  });
}
