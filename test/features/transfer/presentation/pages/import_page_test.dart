import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Import is the master-detail hub for File Import, Dive Computers and
/// Cloud -- everything that used to live under `/transfer` except File
/// Export, which is now its own page (see export_page_test.dart).
void main() {
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/import',
        builder: (context, state) => const TransferPage(),
      ),
    ],
  );

  Future<GoRouter> pumpImport(
    WidgetTester tester, {
    String initialLocation = '/import',
    required Size surfaceSize,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = buildRouter(initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('desktop shows exactly the three import master tiles', (
    tester,
  ) async {
    await pumpImport(tester, surfaceSize: const Size(1400, 900));

    expect(find.text('File Import'), findsOneWidget);
    expect(find.text('Dive Computers'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('File Export'), findsNothing);
  });

  testWidgets('mobile section list also omits File Export', (tester) async {
    await pumpImport(tester, surfaceSize: const Size(420, 900));

    expect(find.text('File Import'), findsOneWidget);
    expect(find.text('Dive Computers'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('File Export'), findsNothing);
  });

  testWidgets('mobile back from a section detail lands on /import', (
    tester,
  ) async {
    final router = await pumpImport(
      tester,
      initialLocation: '/import?selected=computers',
      surfaceSize: const Size(420, 900),
    );

    expect(find.text('Dive Computers'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/import');
  });
}
