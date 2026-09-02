import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_saved_tanks_bar.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

/// The saved-tanks bar sits above the plan's tanks, closed. Opening it shows
/// every saved cylinder as its own object, and tapping one adds it to the
/// plan with its gas - the diver's rig, a tap away from any plan. Saving is
/// one tank at a time, chosen from the plan's tanks and named by the diver.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime(2026, 9, 2);

CylinderConfigItem _item(
  String id,
  String label, {
  double o2 = 21,
  double volume = 11.1,
  TankRole role = TankRole.backGas,
}) => CylinderConfigItem(
  id: id,
  configId: 'cfg',
  label: label,
  tankRole: role,
  volumeL: volume,
  workingPressureBar: 207,
  o2Percent: o2,
  defaultStartPressureBar: 200,
  createdAt: _now,
  updatedAt: _now,
);

final _saved = CylinderConfig(
  id: 'cfg',
  name: 'Saved tanks',
  items: [
    _item('i1', 'D12', volume: 24),
    _item('i2', 'S80 EAN50', o2: 50, role: TankRole.deco),
  ],
  createdAt: _now,
  updatedAt: _now,
);

Widget _harness(List<CylinderConfig> configs) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    cylinderConfigsProvider.overrideWith((ref) async => configs),
  ],
  child: const SizedBox(
    width: 500,
    height: 700,
    child: SingleChildScrollView(child: PlanTankList()),
  ),
);

void main() {
  testWidgets('starts closed, showing how many saved tanks there are', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    expect(find.text('Saved tanks (2)'), findsOneWidget);
    expect(find.text('D12'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('opens into the saved cylinders, each its own chip', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();

    expect(find.text('D12'), findsOneWidget);
    expect(find.text('S80 EAN50'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Save a tank'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
  });

  testWidgets('tapping a saved cylinder adds it to the plan with its gas', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    final before = container.read(divePlanNotifierProvider).tanks.length;

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S80 EAN50'));
    await tester.pumpAndSettle();

    final tanks = container.read(divePlanNotifierProvider).tanks;
    expect(tanks.length, before + 1);
    final added = tanks.last;
    expect(added.name, 'S80 EAN50');
    expect(added.gasMix.o2, 50);
    expect(added.volume, 11.1);
    expect(added.role, TankRole.deco);
    expect(added.order, before);
    // The saved cylinder is still offered: picking is a copy, not a move.
    expect(find.text('S80 EAN50'), findsNWidgets(2));
  });

  testWidgets('saving offers the plan tanks one at a time, then asks for a '
      'tank name', (tester) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a tank'));
    await tester.pumpAndSettle();

    // The default plan has one tank; the menu lists it.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    final planTank = container.read(divePlanNotifierProvider).tanks.single;
    final menuEntry = find.textContaining(planTank.gasMix.name).last;
    await tester.tap(menuEntry);
    await tester.pumpAndSettle();

    expect(find.text('Save tank as'), findsOneWidget);
    expect(find.text('Tank name'), findsOneWidget);
    expect(find.text('Plan Name'), findsNothing);
  });

  testWidgets('with nothing saved it explains how to save', (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('Saved tanks'), findsOneWidget);
    await tester.tap(find.text('Saved tanks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved tanks yet'), findsOneWidget);
  });
}
