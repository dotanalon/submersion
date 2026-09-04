import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/transfer/presentation/widgets/csv_export_dialog.dart';
import 'package:submersion/features/transfer/presentation/widgets/pdf_export_dialog.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_section_widgets.dart';

/// Export section content
class ExportSectionContent extends ConsumerWidget {
  const ExportSectionContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransferSectionHeader(context.l10n.transfer_export_sectionHeader),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(context.l10n.transfer_export_pdfTitle),
                  subtitle: Text(context.l10n.transfer_export_pdfSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handlePdfExport(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(context.l10n.transfer_export_uddfTitle),
                  subtitle: Text(context.l10n.transfer_export_uddfSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_uddfTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportDivesToUddf(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveUddfToFile(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: Text(context.l10n.transfer_export_csvTitle),
                  subtitle: Text(context.l10n.transfer_export_csvSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handleCsvExport(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TransferSectionHeader(context.l10n.transfer_export_multiFormatHeader),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: Text(context.l10n.transfer_export_excelTitle),
                  subtitle: Text(context.l10n.transfer_export_excelSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_excelTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportToExcel(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveExcelToFile(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(context.l10n.transfer_export_maintenanceTitle),
                  subtitle: Text(
                    context.l10n.transfer_export_maintenanceSubtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_maintenanceTitle,
                    shareAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .exportMaintenanceLog(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveMaintenanceLogToFile(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(context.l10n.transfer_export_kmlTitle),
                  subtitle: Text(context.l10n.transfer_export_kmlSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(
                    context,
                    ref,
                    title: context.l10n.transfer_export_kmlTitle,
                    shareAction: () =>
                        ref.read(exportNotifierProvider.notifier).exportToKml(),
                    saveAction: () => ref
                        .read(exportNotifierProvider.notifier)
                        .saveKmlToFile(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TransferInfoCard(
            context.l10n.transfer_export_aboutTitle,
            context.l10n.transfer_export_aboutContent,
            action: TextButton(
              onPressed: () => context.push('/settings/backup'),
              child: Text(context.l10n.transfer_export_backupLink),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle PDF export with options dialog, then share/save options.
  Future<void> _handlePdfExport(BuildContext context, WidgetRef ref) async {
    // Show the PDF export options dialog first
    final options = await PdfExportDialog.show(context);

    // User cancelled or context no longer valid
    if (options == null || !context.mounted) return;

    // Now show share/save options
    _showExportOptions(
      context,
      ref,
      title: context.l10n.transfer_export_pdfTitle,
      shareAction: () =>
          ref.read(exportNotifierProvider.notifier).exportDivesToPdf(options),
      saveAction: () =>
          ref.read(exportNotifierProvider.notifier).savePdfToFile(options),
    );
  }

  /// Handle CSV export with type selection dialog, then share/save options.
  Future<void> _handleCsvExport(BuildContext context, WidgetRef ref) async {
    final type = await CsvExportDialog.show(context);
    if (type == null || !context.mounted) return;

    final notifier = ref.read(exportNotifierProvider.notifier);
    switch (type) {
      case CsvExportType.dives:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionDivesTitle,
          shareAction: () => notifier.exportDivesToCsv(),
          saveAction: () => notifier.saveDivesCsvToFile(),
        );
      case CsvExportType.sites:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionSitesTitle,
          shareAction: () => notifier.exportSitesToCsv(),
          saveAction: () => notifier.saveSitesCsvToFile(),
        );
      case CsvExportType.equipment:
        _showExportOptions(
          context,
          ref,
          title: context.l10n.transfer_csvExport_optionEquipmentTitle,
          shareAction: () => notifier.exportEquipmentToCsv(),
          saveAction: () => notifier.saveEquipmentCsvToFile(),
        );
    }
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() exportFn,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Text(context.l10n.transfer_export_progressExporting),
          ],
        ),
      ),
    );

    try {
      await exportFn();
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            final state = ref.read(exportNotifierProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message ?? context.l10n.transfer_export_completed,
                ),
                backgroundColor: state.status == ExportStatus.success
                    ? Colors.green
                    : Colors.red,
              ),
            );
            ref.read(exportNotifierProvider.notifier).reset();
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.transfer_export_failed('$e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  /// Show export options dialog (Share vs Save to File).
  void _showExportOptions(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<void> Function() shareAction,
    required Future<void> Function() saveAction,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.l10n.transfer_export_optionShareTitle),
                subtitle: Text(
                  context.l10n.transfer_export_optionShareSubtitle,
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _handleExport(context, ref, shareAction);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(context.l10n.transfer_export_optionSaveTitle),
                subtitle: Text(context.l10n.transfer_export_optionSaveSubtitle),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _handleExport(context, ref, saveAction);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
