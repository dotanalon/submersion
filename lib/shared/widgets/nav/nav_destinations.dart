import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Canonical metadata for a single bottom-nav / nav-rail destination.
///
/// The `more` sentinel has [isPinned] `true` and [route] empty -- it represents
/// the overflow control on phone, not a destination.
class NavDestination {
  const NavDestination({
    required this.id,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.subtitle,
    this.isPinned = false,
    this.routeAliases = const [],
  });

  /// Stable kebab-case identifier used for persistence.
  final String id;

  /// Path passed to `context.go(...)`. Empty string for the `more` sentinel.
  final String route;

  final IconData icon;
  final IconData selectedIcon;

  /// Returns the localized label for this destination.
  final String Function(AppLocalizations) label;

  /// Optional localized subtitle, used for Courses, Planning, and GPS Log.
  final String Function(AppLocalizations)? subtitle;

  /// When `true`, this destination cannot be moved between primary and overflow.
  final bool isPinned;

  /// Additional route prefixes that should highlight this destination.
  ///
  /// Used for legacy route trees that still live under an old path (for
  /// example the import wizards under `/transfer`) so the rail keeps the
  /// right item selected while the user is inside them.
  final List<String> routeAliases;

  /// Whether [location] is this destination's route, a sub-path of it, or a
  /// sub-path of one of its [routeAliases].
  ///
  /// The `more` sentinel has an empty route and never matches: an empty
  /// prefix would otherwise match every location.
  bool matches(String location) {
    if (route.isEmpty) return false;
    if (location.startsWith(route)) return true;
    return routeAliases.any(location.startsWith);
  }
}

/// A labeled family of destinations shown together on the wide-screen rail
/// and in the phone overflow sheet.
class NavGroup {
  const NavGroup({
    required this.id,
    required this.label,
    required this.destinations,
  });

  /// Stable kebab-case identifier, used for widget keys.
  final String id;

  /// Returns the localized group header.
  final String Function(AppLocalizations) label;

  /// Members in display order. Pinned destinations never belong to a group.
  final List<NavDestination> destinations;
}

/// A group paired with the subset of its members present in some list.
typedef NavGroupSection = (NavGroup group, List<NavDestination> destinations);

/// Home: pinned first on every surface and outside any group.
final NavDestination kNavHome = NavDestination(
  id: 'dashboard',
  route: '/dashboard',
  icon: Icons.home_outlined,
  selectedIcon: Icons.home,
  label: (l10n) => l10n.nav_home,
  isPinned: true,
);

/// The phone overflow control. Not a destination and not part of the rail.
final NavDestination kNavMore = NavDestination(
  id: 'more',
  route: '',
  icon: Icons.more_horiz_outlined,
  selectedIcon: Icons.more_horiz,
  label: (l10n) => l10n.nav_more,
  isPinned: true,
);

/// The rail groups in display order. [kNavDestinations] is composed from
/// these, so the groups are the single source of truth for ordering.
final List<NavGroup> kNavGroups = List.unmodifiable([
  // Everything a diver touches while logging: the log itself, planning the
  // next dive, getting data in and out, and the places and people involved.
  NavGroup(
    id: 'dives',
    label: (l10n) => l10n.nav_group_dives,
    destinations: List.unmodifiable([
      NavDestination(
        id: 'dives',
        route: '/dives',
        icon: Icons.scuba_diving_outlined,
        selectedIcon: Icons.scuba_diving,
        label: (l10n) => l10n.nav_log,
      ),
      NavDestination(
        id: 'planning',
        route: '/planning',
        icon: Icons.edit_calendar_outlined,
        selectedIcon: Icons.edit_calendar,
        label: (l10n) => l10n.nav_planning,
        subtitle: (l10n) => l10n.nav_planningSubtitle,
      ),
      // The import wizards still live under the legacy `/transfer` tree, so
      // that prefix keeps Import highlighted while a wizard is open.
      NavDestination(
        id: 'import',
        route: '/import',
        icon: Icons.download_outlined,
        selectedIcon: Icons.download,
        label: (l10n) => l10n.nav_import,
        routeAliases: const ['/transfer'],
      ),
      NavDestination(
        id: 'export',
        route: '/export',
        icon: Icons.upload_outlined,
        selectedIcon: Icons.upload,
        label: (l10n) => l10n.nav_export,
      ),
      NavDestination(
        id: 'sites',
        route: '/sites',
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on,
        label: (l10n) => l10n.nav_sites,
      ),
      NavDestination(
        id: 'buddies',
        route: '/buddies',
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
        label: (l10n) => l10n.nav_buddies,
      ),
      NavDestination(
        id: 'trips',
        route: '/trips',
        icon: Icons.flight_outlined,
        selectedIcon: Icons.flight,
        label: (l10n) => l10n.nav_trips,
      ),
    ]),
  ),
  NavGroup(
    id: 'gear-training',
    label: (l10n) => l10n.nav_group_gearTraining,
    destinations: List.unmodifiable([
      NavDestination(
        id: 'equipment',
        route: '/equipment',
        icon: Icons.backpack_outlined,
        selectedIcon: Icons.backpack,
        label: (l10n) => l10n.nav_equipment,
      ),
      NavDestination(
        id: 'dive-centers',
        route: '/dive-centers',
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: (l10n) => l10n.nav_diveCenters,
      ),
      NavDestination(
        id: 'certifications',
        route: '/certifications',
        icon: Icons.card_membership_outlined,
        selectedIcon: Icons.card_membership,
        label: (l10n) => l10n.nav_certifications,
      ),
      NavDestination(
        id: 'courses',
        route: '/courses',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        label: (l10n) => l10n.nav_courses,
        subtitle: (l10n) => l10n.nav_coursesSubtitle,
      ),
      // Material has no fish glyph, so this borrows MDI's and reuses it for
      // the selected state the way `gps-log` reuses its icon.
      NavDestination(
        id: 'species',
        route: '/species',
        icon: MdiIcons.fish,
        selectedIcon: MdiIcons.fish,
        label: (l10n) => l10n.nav_species,
      ),
    ]),
  ),
  NavGroup(
    id: 'tools',
    label: (l10n) => l10n.nav_group_tools,
    destinations: List.unmodifiable([
      NavDestination(
        id: 'statistics',
        route: '/statistics',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: (l10n) => l10n.nav_statistics,
      ),
      NavDestination(
        id: 'media',
        route: '/media',
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
        label: (l10n) => l10n.nav_media,
      ),
      NavDestination(
        id: 'gps-log',
        route: '/gps-log',
        icon: Icons.gps_fixed,
        selectedIcon: Icons.gps_fixed,
        label: (l10n) => l10n.nav_gpsLog,
        subtitle: (l10n) => l10n.tools_gpsLogger_subtitle,
      ),
      NavDestination(
        id: 'settings',
        route: '/settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: (l10n) => l10n.nav_settings,
      ),
    ]),
  ),
]);

/// The complete, ordered list of nav destinations in default wide-screen order.
///
/// Length is **18**: Home, the 16 grouped destinations from [kNavGroups] in
/// group order, and the `more` sentinel.
final List<NavDestination> kNavDestinations = List.unmodifiable([
  kNavHome,
  ...kNavGroups.expand((group) => group.destinations),
  kNavMore,
]);

/// Splits [subset] into its groups, in canonical group and member order.
///
/// Groups with no member in [subset] are omitted, and pinned destinations
/// (which belong to no group) are ignored. The input order of [subset] does
/// not matter; the result always follows [kNavGroups].
List<NavGroupSection> partitionByNavGroup(Iterable<NavDestination> subset) {
  final ids = subset.map((d) => d.id).toSet();
  final sections = <NavGroupSection>[];
  for (final group in kNavGroups) {
    final members = group.destinations
        .where((d) => ids.contains(d.id))
        .toList(growable: false);
    if (members.isNotEmpty) {
      sections.add((group, List.unmodifiable(members)));
    }
  }
  return List.unmodifiable(sections);
}

/// The ids that can be moved between primary slots and overflow.
final List<String> movableNavIds = List.unmodifiable(
  kNavDestinations.where((d) => !d.isPinned).map((d) => d.id),
);

/// Default primary middle-slot ids (slots 2, 3, 4). Matches pre-customization behavior.
const List<String> kDefaultPrimaryIds = ['dives', 'sites', 'trips'];

/// Normalizes a stored list of primary ids into a valid 3-element list.
///
/// Guarantees on the returned list:
/// - Length is exactly 3.
/// - Every id is in [movableIds] (unknown / pinned ids are dropped).
/// - No duplicates (first occurrence wins).
/// - Padding uses [defaults] in order, skipping already-present ids.
///
/// [defaults] must contain at least 3 ids from [movableIds]; otherwise this
/// throws [ArgumentError]. Callers should pass [kDefaultPrimaryIds].
List<String> normalizeNavPrimaryIds({
  required List<String> stored,
  required List<String> movableIds,
  required List<String> defaults,
}) {
  if (defaults.length < 3) {
    throw ArgumentError.value(
      defaults,
      'defaults',
      'must contain at least 3 ids',
    );
  }
  for (final id in defaults.take(3)) {
    if (!movableIds.contains(id)) {
      throw ArgumentError('default id "$id" not in movableIds');
    }
  }

  final result = <String>[];
  for (final id in stored) {
    if (result.length == 3) break;
    if (!movableIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }

  for (final id in defaults) {
    if (result.length == 3) break;
    if (!result.contains(id)) result.add(id);
  }

  return List.unmodifiable(result);
}
