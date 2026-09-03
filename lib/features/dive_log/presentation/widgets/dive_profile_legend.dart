import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/presentation/widgets/chart_zoom_controls.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart';

// Re-exported so consumers of the legend keep a single import for the widget
// and its configuration.
export 'package:submersion/features/dive_log/presentation/widgets/profile_legend_config.dart'
    show ProfileLegendConfig;

/// Control row above the dive profile chart.
///
/// Holds the zoom controls and a button that opens the chart options
/// dropdown, where every metric toggle (including its checkbox) lives. The
/// depth trace is the chart itself and is never listed as an option.
class DiveProfileLegend extends ConsumerWidget {
  final ProfileLegendConfig config;
  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final double leftPadding;

  const DiveProfileLegend({
    super.key,
    required this.config,
    required this.zoomLevel,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.leftPadding = 0.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legendNotifier = ref.read(profileLegendProvider.notifier);

    // Initialize tank pressures if needed
    if (config.hasMultiTankPressure && config.tankPressures != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        legendNotifier.initializeTankPressures(
          config.tankPressures!.keys.toList(),
        );
      });
    }

    // Depth is the chart itself, not an option, so nothing is listed here;
    // the row is just the trailing controls.
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ChartZoomControls(
            zoomLevel: zoomLevel,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onResetZoom: onResetZoom,
          ),
          if (_hasToggles) ...[
            const SizedBox(width: 4),
            _MoreOptionsButton(config: config),
          ],
        ],
      ),
    );
  }

  /// Whether this dive has anything to toggle at all; the options button is
  /// omitted otherwise.
  bool get _hasToggles =>
      config.hasTemperatureData ||
      config.hasPressureData ||
      config.hasEvents ||
      config.hasSecondaryToggles;
}

/// Opens the chart options dialog, where every metric toggle lives.
class _MoreOptionsButton extends ConsumerWidget {
  final ProfileLegendConfig config;

  const _MoreOptionsButton({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _showMoreOptions(context),
      icon: const Icon(Icons.tune, size: 18),
      tooltip: context.l10n.diveLog_profile_tooltip_moreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => ChartOptionsDialog(
        config: config,
        anchorOffset: buttonOffset,
        anchorSize: buttonSize,
      ),
    );
  }
}
