import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/transfer/presentation/widgets/cloud_section_content.dart';
import 'package:submersion/features/transfer/presentation/widgets/computers_section_content.dart';
import 'package:submersion/features/transfer/presentation/widgets/import_section_content.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Main transfer page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with section list on left,
/// selected section content on right.
/// On narrower screens (<800px): Shows section list with navigation.
class TransferPage extends ConsumerWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'transfer',
        masterBuilder: (context, onItemSelected, selectedId) =>
            TransferListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, sectionId) =>
            _buildSectionContent(context, ref, sectionId),
        summaryBuilder: (context) => const _TransferSummaryWidget(),
      );
    }

    // Mobile: Check for selected section via query param
    String? selectedSection;
    try {
      selectedSection = GoRouterState.of(
        context,
      ).uri.queryParameters['selected'];
    } catch (_) {
      // GoRouter not available (e.g., in tests)
    }

    if (selectedSection != null) {
      // Show section detail page
      return _TransferSectionDetailPage(sectionId: selectedSection, ref: ref);
    }

    // Mobile: Show section list
    return const TransferMobileContent();
  }

  /// Builds the appropriate section content based on section ID.
  Widget _buildSectionContent(
    BuildContext context,
    WidgetRef ref,
    String sectionId,
  ) {
    switch (sectionId) {
      case 'import':
        return const ImportSectionContent();
      case 'computers':
        return const ComputersSectionContent();
      case 'cloud':
        return const CloudSectionContent();
      default:
        return Center(
          child: Text(context.l10n.transfer_unknownSection(sectionId)),
        );
    }
  }
}

/// Mobile content showing section list for navigation.
class TransferMobileContent extends StatelessWidget {
  const TransferMobileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'import',
          title: context.l10n.nav_import,
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: transferSections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = transferSections[index];
          return _MobileTransferTile(section: section);
        },
      ),
    );
  }
}

/// Mobile detail page for transfer sections accessed via query params.
class _TransferSectionDetailPage extends ConsumerWidget {
  final String sectionId;
  final WidgetRef ref;

  const _TransferSectionDetailPage({
    required this.sectionId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the section title
    final section = transferSections
        .where((s) => s.id == sectionId)
        .firstOrNull;
    final title = section?.titleBuilder(context) ?? context.l10n.nav_import;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.transfer_detail_backTooltip,
          onPressed: () => context.go(GoRouterState.of(context).uri.path),
        ),
      ),
      body: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (sectionId) {
      case 'import':
        return const ImportSectionContent();
      case 'computers':
        return const ComputersSectionContent();
      case 'cloud':
        return const CloudSectionContent();
      default:
        return Center(
          child: Text(context.l10n.transfer_unknownSection(sectionId)),
        );
    }
  }
}

class _MobileTransferTile extends StatelessWidget {
  final TransferSection section;

  const _MobileTransferTile({required this.section});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = section.color ?? colorScheme.primary;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(section.icon, color: color, size: 24),
      ),
      title: Text(
        section.titleBuilder(context),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        section.subtitleBuilder(context),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _navigateToSection(context, section.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _navigateToSection(BuildContext context, String sectionId) {
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    context.go('$currentPath?selected=$sectionId');
  }
}

// ============================================================================
// SECTION CONTENT WIDGETS
// ============================================================================

/// Summary widget shown when no section is selected (desktop)
class _TransferSummaryWidget extends StatelessWidget {
  const _TransferSummaryWidget();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.sync_alt,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.nav_import,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.transfer_summary_description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.transfer_summary_selectSection,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================
