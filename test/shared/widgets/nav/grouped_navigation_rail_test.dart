import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/grouped_navigation_rail.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  final destinations = kNavDestinations
      .where((d) => d.id != 'more')
      .toList(growable: false);

  Future<void> pump(
    WidgetTester tester, {
    required bool extended,
    int? selectedIndex,
    ValueChanged<int>? onDestinationSelected,
    Widget? leading,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          // Production wraps the rail in a scrolling container so a tall,
          // grouped rail doesn't overflow a short viewport; mirror that here
          // rather than asserting on a bare, unscrollable Column.
          body: SingleChildScrollView(
            child: GroupedNavigationRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected ?? (_) {},
              extended: extended,
              accentOf: (_) => null,
              leading: leading,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one rail per group plus a home rail', (tester) async {
    await pump(tester, extended: true);

    expect(find.byKey(const ValueKey('navRail-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('navRail-dives')), findsOneWidget);
    expect(find.byKey(const ValueKey('navRail-gear-training')), findsOneWidget);
    expect(find.byKey(const ValueKey('navRail-tools')), findsOneWidget);

    final home = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-home')),
    );
    final dives = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-dives')),
    );
    final gearTraining = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-gear-training')),
    );
    final tools = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-tools')),
    );
    expect(home.destinations, hasLength(1));
    expect(dives.destinations, hasLength(7));
    expect(gearTraining.destinations, hasLength(5));
    expect(tools.destinations, hasLength(4));
  });

  testWidgets('leading is attached only to the first (home) rail', (
    tester,
  ) async {
    await pump(
      tester,
      extended: true,
      leading: const Icon(Icons.menu, key: ValueKey('leadingIcon')),
    );

    final home = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-home')),
    );
    final dives = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-dives')),
    );
    expect(home.leading, isNotNull);
    expect(dives.leading, isNull);
    expect(find.byKey(const ValueKey('leadingIcon')), findsOneWidget);
  });

  testWidgets(
    'a flat selectedIndex resolves to the owning rail; others are null',
    (tester) async {
      // Flat index 9 is 'dive-centers', local index 1 in the gear-training
      // group (equipment, dive-centers, certifications, courses, species).
      await pump(tester, extended: true, selectedIndex: 9);

      final home = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('navRail-home')),
      );
      final dives = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('navRail-dives')),
      );
      final gearTraining = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('navRail-gear-training')),
      );
      final tools = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('navRail-tools')),
      );
      expect(home.selectedIndex, isNull);
      expect(dives.selectedIndex, isNull);
      expect(gearTraining.selectedIndex, 1);
      expect(tools.selectedIndex, isNull);
    },
  );

  testWidgets('null selectedIndex leaves every rail unselected', (
    tester,
  ) async {
    await pump(tester, extended: true, selectedIndex: null);

    for (final id in ['home', 'dives', 'gear-training', 'tools']) {
      expect(
        tester
            .widget<NavigationRail>(find.byKey(ValueKey('navRail-$id')))
            .selectedIndex,
        isNull,
      );
    }
  });

  testWidgets('tapping a destination in a later group reports the flat index', (
    tester,
  ) async {
    int? tapped;
    await pump(
      tester,
      extended: true,
      onDestinationSelected: (index) => tapped = index,
    );

    // Local index 2 in the Tools group (statistics, media, gps-log) ->
    // flat index 13 (statistics=13, media=14, gps-log=15, settings=16).
    final tools = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('navRail-tools')),
    );
    tools.onDestinationSelected!(2);
    expect(tapped, 15);
  });

  testWidgets('extended shows group header labels', (tester) async {
    await pump(tester, extended: true);

    expect(find.text('Dives'), findsOneWidget);
    expect(find.text('Gear & Training'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
  });

  testWidgets('compact hides group header labels but keeps dividers', (
    tester,
  ) async {
    await pump(tester, extended: false);
    await tester.pumpAndSettle();

    expect(find.text('Dives'), findsNothing);
    expect(find.text('Gear & Training'), findsNothing);
    expect(find.text('Tools'), findsNothing);
    expect(find.byType(Divider), findsNWidgets(3));
  });

  testWidgets('all rails report the same width', (tester) async {
    await pump(tester, extended: true);

    final widths = [
      for (final id in ['home', 'dives', 'gear-training', 'tools'])
        tester.getSize(find.byKey(ValueKey('navRail-$id'))).width,
    ];
    for (final width in widths.skip(1)) {
      expect(width, widths.first);
    }
  });
}
