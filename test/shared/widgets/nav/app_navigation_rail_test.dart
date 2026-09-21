import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/app_navigation_rail.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

import '../../../helpers/test_app.dart';
import '../../../support/fake_app_settings_repository.dart';

String _labelOf(NavigationRailDestination destination) {
  final label = destination.label;
  if (label is Text) return label.data ?? '';
  return label.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeAppSettingsRepository> pumpRail(
    WidgetTester tester, {
    FakeAppSettingsRepository? repo,
    ValueChanged<int>? onSelected,
    bool extended = true,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resolved = repo ?? FakeAppSettingsRepository();
    await tester.pumpWidget(
      testApp(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(resolved)],
        child: _RailHost(extended: extended, onSelected: onSelected),
      ),
    );
    await tester.pumpAndSettle();
    return resolved;
  }

  testWidgets('renders the stored rail order in a NavigationRail', (
    tester,
  ) async {
    final repo = FakeAppSettingsRepository()
      ..navRailIds = ['settings', 'statistics', 'dives'];
    await pumpRail(tester, repo: repo);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(_labelOf(rail.destinations.first), 'Home');
    expect(_labelOf(rail.destinations[1]), 'Settings');
    expect(_labelOf(rail.destinations[2]), 'Statistics');
    expect(_labelOf(rail.destinations[3]), 'Dives');
    expect(find.byKey(const ValueKey('navRailReorderButton')), findsOneWidget);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    final taps = <int>[];
    await pumpRail(tester, onSelected: taps.add);

    await tester.tap(find.text('Dives'));
    await tester.pumpAndSettle();

    expect(taps, [1]);
  });

  testWidgets('reorder mode pins Home and lists every movable destination', (
    tester,
  ) async {
    await pumpRail(tester);

    await tester.tap(find.byKey(const ValueKey('navRailReorderButton')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const ValueKey('navRailReorderMode')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-rail-pinned-home')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    for (final id in movableNavIds) {
      expect(
        find.byKey(ValueKey('nav-rail-item-$id')),
        findsOneWidget,
        reason: '$id has no row in the sidebar reorder list',
      );
    }
  });

  testWidgets('move-up writes the new rail order through the repository', (
    tester,
  ) async {
    final repo = await pumpRail(tester);

    await tester.tap(find.byKey(const ValueKey('navRailReorderButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Move Sites up'));
    await tester.pumpAndSettle();

    expect(repo.navRailIds!.take(2).toList(), ['sites', 'dives']);
  });

  testWidgets('Done returns to a NavigationRail that follows the new order', (
    tester,
  ) async {
    await pumpRail(tester);

    await tester.tap(find.byKey(const ValueKey('navRailReorderButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move Sites up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navRailReorderDoneButton')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const ValueKey('navRailReorderMode')), findsNothing);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.take(3).map(_labelOf).toList(), [
      'Home',
      'Sites',
      'Dives',
    ]);
  });

  testWidgets('Reset restores the canonical order', (tester) async {
    final repo = FakeAppSettingsRepository()
      ..navRailIds = ['settings', 'statistics'];
    await pumpRail(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('navRailReorderButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navRailReorderResetButton')));
    await tester.pumpAndSettle();

    expect(repo.navRailIds, movableNavIds);

    await tester.tap(find.byKey(const ValueKey('navRailReorderDoneButton')));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(_labelOf(rail.destinations[1]), 'Dives');
  });

  testWidgets('tapping a destination while reordering does not navigate', (
    tester,
  ) async {
    final taps = <int>[];
    await pumpRail(tester, onSelected: taps.add);

    await tester.tap(find.byKey(const ValueKey('navRailReorderButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dives'));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
  });
}

/// Rebuilds [AppNavigationRail] from [navRailDestinationsProvider] so a
/// finished reorder is visible on the NavigationRail that replaces it.
class _RailHost extends ConsumerWidget {
  const _RailHost({required this.extended, this.onSelected});

  final bool extended;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(navRailDestinationsProvider);
    return AppNavigationRail(
      destinations: destinations,
      selectedIndex: 0,
      onDestinationSelected: onSelected ?? (_) {},
      extended: extended,
      labelsHidden: !extended,
      accentOf: (_) => null,
    );
  }
}
