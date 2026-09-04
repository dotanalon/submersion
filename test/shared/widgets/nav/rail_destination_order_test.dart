import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Locks the wide-screen rail contract. The rail is driven from
/// [kNavDestinations], and selection is resolved positionally, so this test
/// encodes the exact (id, route) sequence to stop a refactor from silently
/// reordering or rerouting navigation.
///
/// The order is grouped: Home first, then the Dives, Gear & Training and
/// Tools groups in their canonical order (see [kNavGroups]).
void main() {
  test('kNavDestinations order matches the wide-screen rail contract', () {
    final rail = kNavDestinations.where((d) => d.id != 'more').toList();
    final expected = <(String, String)>[
      ('dashboard', '/dashboard'),
      // Dives
      ('dives', '/dives'),
      ('planning', '/planning'),
      ('import', '/import'),
      ('export', '/export'),
      ('sites', '/sites'),
      ('buddies', '/buddies'),
      ('trips', '/trips'),
      // Gear & Training
      ('equipment', '/equipment'),
      ('dive-centers', '/dive-centers'),
      ('certifications', '/certifications'),
      ('courses', '/courses'),
      ('species', '/species'),
      // Tools
      ('statistics', '/statistics'),
      ('media', '/media'),
      ('gps-log', '/gps-log'),
      ('settings', '/settings'),
    ];
    expect(rail.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(
        (rail[i].id, rail[i].route),
        expected[i],
        reason: 'rail index $i must map to ${expected[i]}',
      );
    }
  });
}
