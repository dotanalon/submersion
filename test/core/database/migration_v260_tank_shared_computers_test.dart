import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tank_shared_computer_backfill.dart';

void main() {
  test('v260 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 260);
    expect(AppDatabase.migrationVersions, contains(260));
    expect(AppDatabase.migrationStepCount(259), 1);
  });

  test('the column is additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  group('inferSharedComputers', () {
    BackfillTank tank(String id, String? computer, double o2) =>
        (id: id, computerId: computer, o2: o2, he: 0, sharedComputerIds: null);

    // The shape a Suunto (21%, 50%) plus Garmin (21%, 50%, O2) fold left:
    // the Garmin's 21% and 50% merged into the Suunto's rows.
    final folded = [
      tank('air', 'suunto', 21),
      tank('ean50', 'suunto', 50),
      tank('o2', 'garmin', 100),
    ];

    test('a secondary shares the primary cylinders it has no gas of its '
        'own for', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: folded,
        ),
        {
          'air': ['garmin'],
          'ean50': ['garmin'],
        },
      );
    });

    test('the primary never takes a secondary-only cylinder', () {
      final shared = inferSharedComputers(
        primaryComputerId: 'suunto',
        secondaryComputerIds: {'garmin'},
        tanks: folded,
      );
      expect(shared.containsKey('o2'), isFalse);
    });

    test('a secondary that kept a tank on that gas does not share it', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: [tank('air', 'suunto', 21), tank('g-air', 'garmin', 21)],
        ),
        isEmpty,
      );
    });

    test('a tank that already records its sharers is left alone', () {
      expect(
        inferSharedComputers(
          primaryComputerId: 'suunto',
          secondaryComputerIds: {'garmin'},
          tanks: [
            (
              id: 'air',
              computerId: 'suunto',
              o2: 21,
              he: 0,
              sharedComputerIds: '["other"]',
            ),
          ],
        ),
        isEmpty,
      );
    });
  });

  test('a v259 database gains the column and its consolidated dives are '
      'backfilled', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 259');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            o2_percent REAL NOT NULL DEFAULT 21,
            he_percent REAL NOT NULL DEFAULT 0,
            tank_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 0
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_data_sources VALUES "
          "('s1', 'd', 'suunto', 1), ('s2', 'd', 'garmin', 0), "
          "('s3', 'solo', 'suunto', 1)",
        );
        rawDb.execute(
          "INSERT INTO dive_tanks VALUES "
          "('air', 'd', 'suunto', 21, 0, 0), "
          "('ean50', 'd', 'suunto', 50, 0, 1), "
          "('o2', 'd', 'garmin', 100, 0, 2), "
          "('solo-air', 'solo', 'suunto', 21, 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, shared_computer_ids FROM dive_tanks ORDER BY id',
        )
        .get();
    expect(
      {
        for (final r in rows)
          r.read<String>('id'): r.read<String?>('shared_computer_ids'),
      },
      {
        'air': '["garmin"]',
        'ean50': '["garmin"]',
        'o2': null,
        'solo-air': null,
      },
    );
  });
}
