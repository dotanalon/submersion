import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/transfer/presentation/pages/export_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Export is a single-section page (no master-detail split, unlike Import),
/// reached directly at `/export`.
void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/export',
    routes: [
      GoRoute(path: '/export', builder: (context, state) => const ExportPage()),
    ],
  );

  Future<void> pumpExport(
    WidgetTester tester, {
    required Size surfaceSize,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: buildRouter(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(420, 900), const Size(1400, 900)]) {
    testWidgets('shows the export title and format tiles at ${size.width}px', (
      tester,
    ) async {
      await pumpExport(tester, surfaceSize: size);

      expect(find.text('Export'), findsWidgets);
      expect(find.text('PDF Logbook'), findsOneWidget);
      expect(find.text('UDDF Export'), findsOneWidget);
      expect(find.text('CSV Export'), findsOneWidget);
    });

    testWidgets('does not offer File Import at ${size.width}px', (
      tester,
    ) async {
      await pumpExport(tester, surfaceSize: size);

      expect(find.text('File Import'), findsNothing);
    });
  }
}
