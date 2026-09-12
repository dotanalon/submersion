import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer still on v207 exports the retired per-metric source columns
/// (`defaultNdlSource` and friends, plus the vestigial
/// `useDiveComputerCnsData`). v208 dropped them locally, so the import path
/// has to ignore those keys on read rather than reject the record -- #767's
/// back-compat requirement. Cross-version sync is otherwise one-directional:
/// the older peer keeps its own NOT NULL columns fed by its own default fills,
/// which is why nothing needs to be emitted for it.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('imports a v207 payload that still carries the source keys', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-legacy',
            diverId: 'diver-legacy',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', 'ds-legacy');
    expect(exported, isNotNull);

    // Nothing local should still be emitting these.
    expect(exported!.keys, isNot(contains('defaultNdlSource')));
    expect(exported.keys, isNot(contains('defaultCeilingSource')));
    expect(exported.keys, isNot(contains('defaultTtsSource')));
    expect(exported.keys, isNot(contains('defaultCnsSource')));
    expect(exported.keys, isNot(contains('defaultDecoStopSource')));
    expect(exported.keys, isNot(contains('defaultGtrSource')));
    expect(exported.keys, isNot(contains('useDiveComputerCnsData')));

    final legacy = Map<String, dynamic>.from(exported)
      ..['defaultNdlSource'] = 0
      ..['defaultCeilingSource'] = 0
      ..['defaultTtsSource'] = 1
      ..['defaultCnsSource'] = 0
      ..['defaultDecoStopSource'] = 1
      ..['defaultGtrSource'] = 0
      ..['useDiveComputerCnsData'] = true;

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-legacy'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-legacy'))).getSingle();
    expect(row.id, 'ds-legacy');
    expect(row.diverId, 'diver-legacy');
  });
}
