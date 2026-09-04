import 'dart:io';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_section_widgets.dart';

/// Dive Computers section content
class ComputersSectionContent extends ConsumerWidget {
  const ComputersSectionContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computersAsync = ref.watch(allDiveComputersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connect new computer
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/dive-computers/discover'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bluetooth_searching,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.transfer_computers_connectTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.transfer_computers_connectSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Known computers list
          computersAsync.when(
            data: (computers) {
              if (computers.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TransferSectionHeader(
                    context.l10n.transfer_computers_knownComputersHeader,
                  ),
                  const SizedBox(height: 8),
                  ...computers.map(
                    (computer) => _buildComputerCard(
                      context,
                      computer,
                      theme,
                      colorScheme,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          if (Platform.isIOS) ...[
            const SizedBox(height: 16),
            TransferSectionHeader(
              context.l10n.transfer_computers_appleWatchHeader,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.watch),
                title: Text(context.l10n.transfer_computers_appleWatchTitle),
                subtitle: Text(
                  context.l10n.transfer_computers_appleWatchSubtitle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/wearable-import'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComputerCard(
    BuildContext context,
    DiveComputer computer,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/dive-computers/${computer.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: computer.isFavorite
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getConnectionIcon(computer.connectionType),
                  size: 20,
                  color: computer.isFavorite
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            computer.displayName,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (computer.isFavorite)
                          Icon(
                            Icons.star,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                    Text(
                      computer.fullName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.scuba_diving,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.transfer_computers_diveCount(
                            computer.diveCount,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatLastDownload(context, computer.lastDownload),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    context.push('/dive-computers/${computer.id}/download'),
                icon: const Icon(Icons.download, size: 20),
                tooltip: context.l10n.transfer_computers_downloadTooltip,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getConnectionIcon(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'bluetooth':
        return Icons.bluetooth;
      case 'ble':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      default:
        return Icons.watch;
    }
  }
}
