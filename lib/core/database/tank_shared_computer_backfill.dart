import 'dart:convert';

import 'package:drift/drift.dart';

/// A dive_tanks row as the v260 backfill sees it.
typedef BackfillTank = ({
  String id,
  String? computerId,
  double o2,
  double he,
  String? sharedComputerIds,
});

/// Same-gas tolerance the consolidation merge uses
/// (DiveConsolidationBuilder._gasTolerancePct).
const double _gasTolerancePct = 0.5;

/// Which computers share which of the primary's cylinders on one dive
/// consolidated before v260 recorded it: tank id -> computer ids.
///
/// Consolidation merges a secondary's cylinder only into a PRIMARY tank
/// with the same gas, and drops the secondary's row. So a secondary
/// computer that has no cylinder of its own on a primary tank's gas once
/// had one there, merged away: it shares that tank. Its own remaining
/// tanks are the ones that matched nothing. Tanks of other secondaries are
/// never merge targets, so they are never shared. A tank that already
/// records its sharers is left alone.
Map<String, List<String>> inferSharedComputers({
  required String primaryComputerId,
  required Set<String> secondaryComputerIds,
  required List<BackfillTank> tanks,
}) {
  bool sameGas(BackfillTank a, BackfillTank b) =>
      (a.o2 - b.o2).abs() <= _gasTolerancePct &&
      (a.he - b.he).abs() <= _gasTolerancePct;

  final result = <String, List<String>>{};
  for (final tank in tanks) {
    if (tank.computerId != primaryComputerId) continue;
    if (tank.sharedComputerIds?.trim().isNotEmpty ?? false) continue;
    final sharers = [
      for (final computer in secondaryComputerIds.toList()..sort())
        if (!tanks.any((t) => t.computerId == computer && sameGas(t, tank)))
          computer,
    ];
    if (sharers.isNotEmpty) result[tank.id] = sharers;
  }
  return result;
}

/// v260: fills `dive_tanks.shared_computer_ids` on dives consolidated before
/// the fold recorded it (see [inferSharedComputers]).
///
/// Local-only and idempotent: deterministic from rows every device holds,
/// so no HLC bump and nothing marked pending; a tank that already records
/// its sharers is skipped. A no-op until the column exists.
Future<void> backfillTankSharedComputers(DatabaseConnectionUser db) async {
  Future<bool> hasColumns(String table, List<String> names) async {
    final cols = {
      for (final c
          in await db.customSelect("PRAGMA table_info('$table')").get())
        c.read<String>('name'),
    };
    return cols.containsAll(names);
  }

  // A no-op until the column exists, and on a partial-schema fixture that
  // lacks what the inference reads.
  if (!await hasColumns('dive_tanks', [
        'shared_computer_ids',
        'computer_id',
        'o2_percent',
        'he_percent',
      ]) ||
      !await hasColumns('dive_data_sources', ['computer_id', 'is_primary'])) {
    return;
  }

  // Consolidated dives: a primary source with a computer, plus at least one
  // other computer.
  final sources = await db.customSelect('''
    SELECT dive_id, computer_id, is_primary FROM dive_data_sources
    WHERE computer_id IS NOT NULL AND dive_id IN (
      SELECT dive_id FROM dive_data_sources
      WHERE computer_id IS NOT NULL
      GROUP BY dive_id HAVING COUNT(DISTINCT computer_id) > 1
    )
  ''').get();
  final primaryByDive = <String, String>{};
  final computersByDive = <String, Set<String>>{};
  for (final row in sources) {
    final diveId = row.read<String>('dive_id');
    final computerId = row.read<String>('computer_id');
    computersByDive.putIfAbsent(diveId, () => <String>{}).add(computerId);
    if (row.read<bool>('is_primary')) primaryByDive[diveId] = computerId;
  }

  for (final entry in primaryByDive.entries) {
    final tankRows = await db
        .customSelect(
          'SELECT id, computer_id, o2_percent, he_percent, '
          'shared_computer_ids FROM dive_tanks WHERE dive_id = ?',
          variables: [Variable<String>(entry.key)],
        )
        .get();
    final shared = inferSharedComputers(
      primaryComputerId: entry.value,
      secondaryComputerIds: computersByDive[entry.key]!.difference({
        entry.value,
      }),
      tanks: [
        for (final r in tankRows)
          (
            id: r.read<String>('id'),
            computerId: r.read<String?>('computer_id'),
            o2: r.read<double>('o2_percent'),
            he: r.read<double>('he_percent'),
            sharedComputerIds: r.read<String?>('shared_computer_ids'),
          ),
      ],
    );
    for (final tank in shared.entries) {
      await db.customUpdate(
        'UPDATE dive_tanks SET shared_computer_ids = ? WHERE id = ?',
        variables: [
          Variable<String>(jsonEncode(tank.value)),
          Variable<String>(tank.key),
        ],
      );
    }
  }
}
