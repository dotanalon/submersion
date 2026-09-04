import 'package:flutter/material.dart';

import 'package:submersion/features/transfer/presentation/widgets/export_section_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// The file export page, reached from the "Export" rail/nav destination.
///
/// Unlike [TransferPage] this hosts a single section, so a master-detail
/// split would show an empty summary pane most of the time -- the content is
/// centered directly instead, at every width.
class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'export',
          title: context.l10n.nav_export,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const ExportSectionContent(),
        ),
      ),
    );
  }
}
