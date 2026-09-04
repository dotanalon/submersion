import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('kNavDestinations', () {
    test('has exactly 18 entries (17 routable + more sentinel)', () {
      expect(kNavDestinations.length, 18);
    });

    test('exactly two entries are pinned (dashboard and more)', () {
      final pinned = kNavDestinations.where((d) => d.isPinned).toList();
      expect(pinned.length, 2);
      expect(pinned.map((d) => d.id).toSet(), {'dashboard', 'more'});
    });

    test('ids are unique', () {
      final ids = kNavDestinations.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids match kebab-case pattern', () {
      final pattern = RegExp(r'^[a-z][a-z-]*$');
      for (final d in kNavDestinations) {
        expect(pattern.hasMatch(d.id), isTrue, reason: 'bad id: ${d.id}');
      }
    });

    test('contains the expected 17 routable ids plus more sentinel', () {
      expect(kNavDestinations.map((d) => d.id).toList(), [
        'dashboard',
        'dives',
        'planning',
        'import',
        'export',
        'sites',
        'buddies',
        'trips',
        'equipment',
        'dive-centers',
        'certifications',
        'courses',
        'species',
        'statistics',
        'media',
        'gps-log',
        'settings',
        'more',
      ]);
    });

    test(
      'routable destinations have non-empty route; more sentinel has empty route',
      () {
        for (final d in kNavDestinations) {
          if (d.id == 'more') {
            expect(d.route, '');
          } else {
            expect(d.route, isNotEmpty);
          }
        }
      },
    );

    test('no longer contains the retired transfer destination', () {
      expect(kNavDestinations.map((d) => d.id), isNot(contains('transfer')));
    });
  });

  group('kNavGroups', () {
    test('has the three groups in rail order', () {
      expect(kNavGroups.map((g) => g.id).toList(), [
        'dives',
        'gear-training',
        'tools',
      ]);
    });

    test('groups own the expected destinations', () {
      final byId = {for (final g in kNavGroups) g.id: g};
      expect(byId['dives']!.destinations.map((d) => d.id).toList(), [
        'dives',
        'planning',
        'import',
        'export',
        'sites',
        'buddies',
        'trips',
      ]);
      expect(byId['gear-training']!.destinations.map((d) => d.id).toList(), [
        'equipment',
        'dive-centers',
        'certifications',
        'courses',
        'species',
      ]);
      expect(byId['tools']!.destinations.map((d) => d.id).toList(), [
        'statistics',
        'media',
        'gps-log',
        'settings',
      ]);
    });

    test('every non-pinned destination belongs to exactly one group', () {
      final grouped = kNavGroups.expand((g) => g.destinations).map((d) => d.id);
      final groupedList = grouped.toList();
      expect(groupedList.toSet().length, groupedList.length);
      final nonPinned = kNavDestinations
          .where((d) => !d.isPinned)
          .map((d) => d.id);
      expect(groupedList.toSet(), nonPinned.toSet());
    });

    test('pinned destinations are not in any group', () {
      final grouped = kNavGroups
          .expand((g) => g.destinations)
          .map((d) => d.id)
          .toSet();
      expect(grouped, isNot(contains('dashboard')));
      expect(grouped, isNot(contains('more')));
    });
  });

  group('partitionByNavGroup', () {
    test('partitions the full rail list into all three groups in order', () {
      final rail = kNavDestinations.where((d) => !d.isPinned);
      final sections = partitionByNavGroup(rail);
      expect(sections.map((s) => s.$1.id).toList(), [
        'dives',
        'gear-training',
        'tools',
      ]);
      expect(sections[0].$2.length, 7);
      expect(sections[1].$2.length, 5);
      expect(sections[2].$2.length, 4);
    });

    test('drops groups with no members in the subset', () {
      final byId = {for (final d in kNavDestinations) d.id: d};
      final sections = partitionByNavGroup([byId['settings']!, byId['sites']!]);
      expect(sections.map((s) => s.$1.id).toList(), ['dives', 'tools']);
    });

    test('orders members canonically regardless of input order', () {
      final byId = {for (final d in kNavDestinations) d.id: d};
      final sections = partitionByNavGroup([
        byId['trips']!,
        byId['dives']!,
        byId['sites']!,
      ]);
      expect(sections.single.$2.map((d) => d.id).toList(), [
        'dives',
        'sites',
        'trips',
      ]);
    });

    test('ignores pinned destinations', () {
      final byId = {for (final d in kNavDestinations) d.id: d};
      expect(partitionByNavGroup([byId['dashboard']!, byId['more']!]), isEmpty);
    });
  });

  group('NavDestination.matches', () {
    final byId = {for (final d in kNavDestinations) d.id: d};

    test('matches its own route and sub-paths', () {
      expect(byId['dives']!.matches('/dives'), isTrue);
      expect(byId['dives']!.matches('/dives/42'), isTrue);
      expect(byId['dives']!.matches('/sites'), isFalse);
    });

    test('import matches the legacy transfer routes via alias', () {
      expect(byId['import']!.matches('/import'), isTrue);
      expect(byId['import']!.matches('/transfer'), isTrue);
      expect(byId['import']!.matches('/transfer/import-wizard'), isTrue);
      expect(byId['import']!.matches('/transfer/import-cloud/suunto'), isTrue);
    });

    test('export does not match import or transfer routes', () {
      expect(byId['export']!.matches('/export'), isTrue);
      expect(byId['export']!.matches('/import'), isFalse);
      expect(byId['export']!.matches('/transfer'), isFalse);
    });

    test('more sentinel never matches', () {
      expect(byId['more']!.matches('/dives'), isFalse);
      expect(byId['more']!.matches(''), isFalse);
    });
  });

  group('movableNavIds', () {
    test('is kNavDestinations minus dashboard and more, in order', () {
      expect(movableNavIds, [
        'dives',
        'planning',
        'import',
        'export',
        'sites',
        'buddies',
        'trips',
        'equipment',
        'dive-centers',
        'certifications',
        'courses',
        'species',
        'statistics',
        'media',
        'gps-log',
        'settings',
      ]);
    });

    test('has exactly 16 entries', () {
      expect(movableNavIds.length, 16);
    });
  });
}
