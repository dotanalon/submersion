import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

/// Wide-screen navigation rail with an in-place reorder mode.
///
/// Normal navigation uses [NavigationRail]. The trailing control switches the
/// rail into a reorderable list so the diver can arrange destinations without
/// leaving the sidebar; Home stays pinned at the top. The resulting order is
/// written through [navRailOrderNotifierProvider].
class AppNavigationRail extends ConsumerStatefulWidget {
  const AppNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.labelsHidden,
    required this.accentOf,
    this.leading,
    this.minExtendedWidth = 190,
  });

  /// Routable destinations in the order they should appear, Home first.
  final List<NavDestination> destinations;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  /// When true, destination icons carry a hover tooltip because the rail is
  /// not showing labels.
  final bool labelsHidden;
  final Color? Function(String id) accentOf;
  final Widget? leading;
  final double minExtendedWidth;

  @override
  ConsumerState<AppNavigationRail> createState() => _AppNavigationRailState();
}

class _AppNavigationRailState extends ConsumerState<AppNavigationRail> {
  bool _reordering = false;

  /// Local mirror of the movable ids while a reorder is in progress, so a
  /// drag can paint immediately and a failed save can roll back.
  List<String>? _local;

  Map<String, NavDestination> get _byId => {
    for (final destination in widget.destinations) destination.id: destination,
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(navRailOrderNotifierProvider, (previous, next) {
      if (!_reordering || listEquals(_local, next)) return;
      setState(() => _local = List<String>.from(next));
    });

    if (_reordering) return _buildReorderRail(context);
    return _buildRail(context);
  }

  Widget _buildRail(BuildContext context) {
    final l10n = context.l10n;
    return NavigationRail(
      extended: widget.extended,
      minExtendedWidth: widget.minExtendedWidth,
      scrollable: true,
      trailingAtBottom: true,
      leading: widget.leading,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      trailing: IconButton(
        key: const ValueKey('navRailReorderButton'),
        icon: const Icon(Icons.reorder),
        tooltip: l10n.nav_tooltip_reorderMenu,
        onPressed: _enterReorder,
      ),
      destinations: [
        for (final destination in widget.destinations)
          NavigationRailDestination(
            icon: _railIcon(
              Icon(destination.icon, color: widget.accentOf(destination.id)),
              label: destination.label(l10n),
            ),
            selectedIcon: _railIcon(
              Icon(
                destination.selectedIcon,
                color: widget.accentOf(destination.id),
              ),
              label: destination.label(l10n),
            ),
            label: Text(destination.label(l10n)),
          ),
      ],
    );
  }

  Widget _buildReorderRail(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final byId = _byId;
    final home = byId['dashboard'];
    final order = _local ?? const <String>[];
    final listIsDefault = listEquals(order, kDefaultNavOrder);
    final background =
        NavigationRailTheme.of(context).backgroundColor ??
        theme.colorScheme.surface;

    return Material(
      key: const ValueKey('navRailReorderMode'),
      color: background,
      child: SizedBox(
        width: widget.minExtendedWidth,
        child: Column(
          children: [
            if (widget.leading != null) widget.leading!,
            if (home != null)
              ListTile(
                key: const ValueKey('nav-rail-pinned-home'),
                leading: Icon(home.icon, color: widget.accentOf(home.id)),
                title: Text(home.label(l10n)),
                trailing: Tooltip(
                  message: l10n.settings_navCustomization_pinnedTooltip,
                  child: const Icon(Icons.lock_outline),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                key: const ValueKey('navRailReorderList'),
                buildDefaultDragHandles: false,
                itemExtent: _kReorderRowHeight,
                itemCount: order.length,
                onReorderItem: _commitReorder,
                itemBuilder: (context, index) {
                  final id = order[index];
                  final destination = byId[id];
                  if (destination == null) {
                    return SizedBox.shrink(
                      key: ValueKey('nav-rail-missing-$id'),
                    );
                  }
                  return _RailReorderTile(
                    key: ValueKey('nav-rail-item-$id'),
                    index: index,
                    isFirst: index == 0,
                    isLast: index == order.length - 1,
                    destination: destination,
                    accent: widget.accentOf(id),
                    selected:
                        widget.destinations.indexWhere((d) => d.id == id) ==
                        widget.selectedIndex,
                    onMoveUp: () => _commitReorder(index, index - 1),
                    onMoveDown: () => _commitReorder(index, index + 1),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    key: const ValueKey('navRailReorderResetButton'),
                    icon: const Icon(Icons.restore),
                    tooltip: l10n.settings_navCustomization_resetButton,
                    onPressed: listIsDefault ? null : _reset,
                  ),
                  IconButton(
                    key: const ValueKey('navRailReorderDoneButton'),
                    icon: const Icon(Icons.check),
                    tooltip: l10n.nav_tooltip_doneReordering,
                    onPressed: _exitReorder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enterReorder() {
    setState(() {
      _reordering = true;
      _local = widget.destinations
          .where((destination) => destination.id != 'dashboard')
          .map((destination) => destination.id)
          .toList();
    });
  }

  void _exitReorder() {
    setState(() {
      _reordering = false;
      _local = null;
    });
  }

  Future<void> _reset() async {
    final previous = _local;
    try {
      await ref.read(navRailOrderNotifierProvider.notifier).resetToDefaults();
      if (!mounted) return;
      setState(() => _local = List<String>.from(kDefaultNavOrder));
    } catch (_) {
      if (!mounted) return;
      setState(() => _local = previous);
      _showSaveError();
    }
  }

  Future<void> _commitReorder(int oldIndex, int newIndex) async {
    final previous = _local;
    if (previous == null) return;
    final next = _moveItem(previous, from: oldIndex, to: newIndex);
    if (listEquals(next, previous)) return;
    setState(() => _local = next);
    try {
      await ref.read(navRailOrderNotifierProvider.notifier).setOrder(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _local = previous);
      _showSaveError();
    }
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_navCustomization_saveError)),
    );
  }

  Widget _railIcon(Icon icon, {required String label}) {
    if (!widget.labelsHidden) return icon;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      positionDelegate: (position) => _besideRail(position, towardsLeft: isRtl),
      child: icon,
    );
  }
}

const double _kReorderRowHeight = 48;

List<String> _moveItem(
  List<String> items, {
  required int from,
  required int to,
}) {
  if (from < 0 || from >= items.length) return items;
  final copy = List<String>.from(items);
  final item = copy.removeAt(from);
  copy.insert(to.clamp(0, copy.length), item);
  return copy;
}

/// One movable destination in rail reorder mode.
class _RailReorderTile extends StatelessWidget {
  const _RailReorderTile({
    super.key,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.destination,
    required this.accent,
    required this.selected,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final bool isFirst;
  final bool isLast;
  final NavDestination destination;
  final Color? accent;
  final bool selected;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = destination.label(l10n);
    return ListTile(
      selected: selected,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      horizontalTitleGap: 8,
      leading: Icon(destination.icon, color: accent),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: l10n.settings_navCustomization_moveUpLabel(label),
            onPressed: isFirst ? null : onMoveUp,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: l10n.settings_navCustomization_moveDownLabel(label),
            onPressed: isLast ? null : onMoveDown,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }
}

/// Places a rail tooltip beside the rail, vertically centred on its icon,
/// so it never covers the neighbouring destinations above or below.
Offset _besideRail(
  TooltipPositionContext position, {
  required bool towardsLeft,
}) {
  const gap = 36.0;
  final tooltip = position.tooltipSize;
  final x = towardsLeft
      ? position.target.dx - gap - tooltip.width
      : position.target.dx + gap;
  final y = position.target.dy - tooltip.height / 2;
  return Offset(
    x.clamp(0.0, math.max(0.0, position.overlaySize.width - tooltip.width)),
    y.clamp(0.0, math.max(0.0, position.overlaySize.height - tooltip.height)),
  );
}
