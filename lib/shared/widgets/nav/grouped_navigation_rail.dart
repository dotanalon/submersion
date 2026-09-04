import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// The wide-screen navigation rail, rendered as one [NavigationRail] per
/// [NavGroup] with a header between groups.
///
/// Flutter's [NavigationRail] lays its destinations out itself and cannot
/// host arbitrary widgets between them, so grouping is done by stacking one
/// rail per group. Each rail owns a slice of [destinations]; [selectedIndex]
/// and [onDestinationSelected] speak in flat indices into [destinations], so
/// the caller does not need to know about the grouping.
///
/// Stacking rails keeps the Material 3 indicator, tooltips, focus handling
/// and the extend animation for free. The accepted trade-offs:
/// - screen readers announce "tab n of m" within a group, not the whole rail;
/// - each rail adds its own 8 px top spacer, which the header padding is
///   tuned around.
class GroupedNavigationRail extends StatelessWidget {
  const GroupedNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.accentOf,
    this.leading,
    this.minExtendedWidth = 190,
  });

  /// Every routable destination in rail order. Must not contain `more`.
  final List<NavDestination> destinations;

  /// Index into [destinations] of the selected item, or null for none.
  final int? selectedIndex;

  /// Called with the index into [destinations] of the tapped item.
  final ValueChanged<int> onDestinationSelected;

  /// Whether labels are shown beside icons. Group header text is only shown
  /// when extended; the compact rail separates groups with a divider alone.
  final bool extended;

  /// Accent color per destination id; null leaves the Material default.
  final Color? Function(String id) accentOf;

  /// Shown above the first rail (the collapse toggle).
  final Widget? leading;

  final double minExtendedWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        NavigationRailTheme.of(context).backgroundColor ??
        theme.colorScheme.surface;
    final indexOf = <String, int>{
      for (var i = 0; i < destinations.length; i++) destinations[i].id: i,
    };
    final pinned = destinations
        .where((d) => d.isPinned)
        .toList(growable: false);
    final sections = partitionByNavGroup(
      destinations.where((d) => !d.isPinned),
    );

    // The leading widget belongs to whichever rail comes first.
    var leadingSlot = leading;
    Widget? takeLeading() {
      final widget = leadingSlot;
      leadingSlot = null;
      return widget;
    }

    // The rail paints only behind its own rails; this Material covers the
    // headers and the slack below the last group in the same surface color.
    return Material(
      color: background,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pinned.isNotEmpty)
              _buildRail(
                context,
                railId: 'home',
                members: pinned,
                indexOf: indexOf,
                leading: takeLeading(),
              ),
            for (final (group, members) in sections) ...[
              _RailGroupHeader(
                key: ValueKey('navRailHeader-${group.id}'),
                label: group.label(context.l10n),
                extended: extended,
              ),
              _buildRail(
                context,
                railId: group.id,
                members: members,
                indexOf: indexOf,
                leading: takeLeading(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRail(
    BuildContext context, {
    required String railId,
    required List<NavDestination> members,
    required Map<String, int> indexOf,
    Widget? leading,
  }) {
    final l10n = context.l10n;
    final localSelected = members.indexWhere(
      (d) => indexOf[d.id] == selectedIndex,
    );
    // NavigationRail's body is a Flexible column, so it needs a bounded
    // height; IntrinsicHeight supplies one inside the scrolling parent.
    return IntrinsicHeight(
      child: NavigationRail(
        key: ValueKey('navRail-$railId'),
        extended: extended,
        minExtendedWidth: minExtendedWidth,
        leading: leading,
        selectedIndex: localSelected >= 0 ? localSelected : null,
        onDestinationSelected: (index) =>
            onDestinationSelected(indexOf[members[index].id]!),
        destinations: [
          for (final destination in members)
            NavigationRailDestination(
              icon: Icon(destination.icon, color: accentOf(destination.id)),
              selectedIcon: Icon(
                destination.selectedIcon,
                color: accentOf(destination.id),
              ),
              label: Text(destination.label(l10n)),
            ),
        ],
      ),
    );
  }
}

/// Divider plus, when the rail is extended, the group's label.
///
/// The label animates in and out with [AnimatedSize] so it tracks the rail's
/// own extend animation instead of popping.
class _RailGroupHeader extends StatelessWidget {
  const _RailGroupHeader({
    super.key,
    required this.label,
    required this.extended,
  });

  final String label;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Divider(height: 1, indent: 12, endIndent: 12),
        ),
        AnimatedSize(
          duration: kThemeAnimationDuration,
          alignment: Alignment.topLeft,
          child: extended
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
