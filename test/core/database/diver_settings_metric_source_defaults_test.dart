import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// The six per-metric data-source columns on diver_settings. A
/// MetricDataSource index: 0 = computer, 1 = calculated.
const _sourceColumns = [
  'default_ndl_source',
  'default_ceiling_source',
  'default_deco_stop_source',
  'default_tts_source',
  'default_cns_source',
  'default_gtr_source',
];

/// An existing library already at the current schema version: a
/// diver_settings table carrying the source columns at their old calculated
/// column default, holding [stored] in every one of them. No rung runs on
/// open, so this isolates the beforeOpen backstops.
NativeDatabase _existingLibrary({required int stored}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
      );
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          ${_sourceColumns.map((c) => '$c INTEGER NOT NULL DEFAULT 1').join(',\n          ')}
        )
      ''');
      rawDb.execute(
        'INSERT INTO diver_settings (id, ${_sourceColumns.join(', ')}) '
        "VALUES ('settings', ${List.filled(_sourceColumns.length, stored).join(', ')})",
      );
    },
  );
}

Future<Map<String, int>> _storedSources(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT ${_sourceColumns.join(', ')} FROM diver_settings')
      .getSingle();
  return {for (final c in _sourceColumns) c: row.read<int>(c)};
}

void main() {
  test('a fresh database defaults every source column to computer', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    for (final name in _sourceColumns) {
      final column = cols.firstWhere((c) => c.read<String>('name') == name);
      expect(
        column.read<String?>('dflt_value'),
        '0',
        reason: '$name should default to computer',
      );
    }
  });

  // The computer default is for fresh databases only (#1859). A 0/1 column
  // cannot tell a deliberate Calculated choice from an untouched default, so
  // opening an existing library must never rewrite what it stored. The v133
  // and v177 migration tests cover the same guarantee across the ladder.
  test('opening an existing library keeps stored calculated sources', () async {
    final db = AppDatabase(_existingLibrary(stored: 1));
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 1});
  });

  test('opening an existing library keeps stored computer sources', () async {
    final db = AppDatabase(_existingLibrary(stored: 0));
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 0});
  });
}
