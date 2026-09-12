import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(ExpansionTile), matching: matching);

Future<void> _pumpLegend(
  WidgetTester tester, {
  required ProfileLegendConfig config,
  // Must fit the 800px test surface: the options button is right-aligned,
  // so a wider box would push it off-screen and the tap would miss.
  double width = 600,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DiveProfileLegend(
            config: config,
            zoomLevel: 1.0,
            onZoomIn: () {},
            onZoomOut: () {},
            onResetZoom: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  // One dialog per test: re-pumping the same app type updates the existing
  // tree, so an already-open dialog's barrier would swallow the second tap.
  testWidgets('offers no GTR toggle when the dive has no GTR data', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      config: const ProfileLegendConfig(hasTtsData: true),
    );
    await _openDialog(tester);
    expect(_inDialog(find.text('TTS')), findsOneWidget);
    expect(find.text('GTR'), findsNothing);
  });

  testWidgets('offers a GTR toggle when the dive has GTR data', (tester) async {
    await _pumpLegend(
      tester,
      config: const ProfileLegendConfig(hasTtsData: true, hasGtrData: true),
    );
    await _openDialog(tester);
    expect(_inDialog(find.text('GTR')), findsOneWidget);
  });

  testWidgets('the options dialog renders GTR as a plain visibility toggle', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      width: 300,
      config: const ProfileLegendConfig(hasTtsData: true, hasGtrData: true),
    );
    await _openDialog(tester);

    expect(_inDialog(find.text('GTR')), findsOneWidget);
    // Every metric is calculated now, so the row is an ordinary check box
    // with no Computer/Calculated selector beside it.
    final gtrRow = find
        .ancestor(of: _inDialog(find.text('GTR')), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: gtrRow,
        matching: find.byIcon(Icons.check_box_outline_blank),
      ),
      findsOneWidget,
    );
    expect(_inDialog(find.text('DC')), findsNothing);
    expect(_inDialog(find.text('Calc')), findsNothing);
  });
}
