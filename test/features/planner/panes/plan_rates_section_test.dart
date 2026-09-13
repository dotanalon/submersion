import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_rates_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({DepthUnit depthUnit = DepthUnit.meters})
    : super(AppSettings(depthUnit: depthUnit));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The rate row labelled [label] ("Ascent rate", "Descent rate").
Finder _row(String label) => find.widgetWithText(PlanNumberField, label);

Finder _field(String label) =>
    find.descendant(of: _row(label), matching: find.byType(TextField));

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

const _ascent = 'Ascent rate';
const _intermediate = 'Intermediate stop ascent rate';
const _shallow = 'Shallow stop ascent rate';
const _descent = 'Descent rate';
String _finalAscent(String depth) => 'Final ascent rate (last $depth)';

void main() {
  testWidgets('shows all five rates as number boxes reflecting plan state', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    // Working ascent, the two deco bands, the final stretch, and descent.
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PlanNumberField), findsNWidgets(5));
    expect(_text(tester, _ascent), '9'); // bottom to first stop
    expect(_text(tester, _intermediate), '6'); // between intermediate stops
    expect(_text(tester, _shallow), '3'); // between shallow stops
    expect(_text(tester, _finalAscent('3m')), '1'); // last stop to surface
    expect(_text(tester, _descent), '18');
    // The unit sits beside each box, once per row.
    expect(find.text('m/min'), findsNWidgets(5));
  });

  testWidgets('each box drives its own rate', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanRatesSection)),
    );

    // Five controls in one column are easy to wire to the wrong callback, and
    // the mistake would be invisible until a schedule came out wrong.
    await tester.enterText(_field(_ascent), '12');
    await tester.enterText(_field(_intermediate), '7');
    await tester.enterText(_field(_shallow), '4');
    await tester.enterText(_field(_finalAscent('3m')), '2');
    await tester.enterText(_field(_descent), '20');
    await tester.pumpAndSettle();

    final state = container.read(divePlanNotifierProvider);
    expect(state.ascentRate, 12);
    expect(state.intermediateAscentRate, 7);
    expect(state.shallowAscentRate, 4);
    expect(state.finalAscentRate, 2);
    expect(state.descentRate, 20);
  });

  testWidgets('rejects a rate outside the 1-30 m/min band', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanRatesSection)),
    );

    await tester.enterText(_field(_ascent), '90');
    await tester.pumpAndSettle();

    expect(container.read(divePlanNotifierProvider).ascentRate, 9);
    expect(
      tester.widget<TextField>(_field(_ascent)).decoration?.errorText,
      isNotNull,
    );
  });

  testWidgets('displays and edits rates in ft/min when depth unit is feet', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(depthUnit: DepthUnit.feet),
          ),
        ],
        child: const SingleChildScrollView(child: PlanRatesSection()),
      ),
    );
    await tester.pumpAndSettle();

    // Defaults shown converted to whole ft/min, with no m/min text. These are
    // the TDI rates a diver taught in imperial would recognise: 30 / 20 / 10
    // off the bottom and down the stops, 3 over the last stretch.
    expect(_text(tester, _ascent), '30'); // 9 m/min
    expect(_text(tester, _intermediate), '20'); // 6 m/min
    expect(_text(tester, _shallow), '10'); // 3 m/min
    expect(_text(tester, _finalAscent('10ft')), '3'); // 1 m/min
    expect(_text(tester, _descent), '59'); // 18 m/min descent
    expect(find.text('ft/min'), findsNWidgets(5));
    expect(find.textContaining('m/min'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanRatesSection)),
    );
    // Editing in ft/min stores the converted m/min value.
    await tester.enterText(_field(_ascent), '33');
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).ascentRate,
      closeTo(33 / 3.28084, 0.001),
    );
  });
}
