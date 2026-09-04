import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_section_widgets.dart';

/// Import section content
class ImportSectionContent extends ConsumerWidget {
  const ImportSectionContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransferSectionHeader(context.l10n.transfer_import_sectionHeader),
          const SizedBox(height: 8),
          // Universal Import (primary entry point)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: context.l10n.transfer_import_fileImportSemanticLabel,
              child: InkWell(
                onTap: () => context.push('/transfer/import-wizard'),
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
                          Icons.upload_file,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.transfer_import_fileImportTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.transfer_import_fileImportSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
          ),
          const SizedBox(height: 16),
          TransferInfoCard(
            context.l10n.transfer_import_aboutTitle,
            context.l10n.transfer_import_aboutContent,
          ),
        ],
      ),
    );
  }
}
