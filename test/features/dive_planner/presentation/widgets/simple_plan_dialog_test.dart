import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

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

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(PlanNumberField, label),
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Widget _harness({DepthUnit depthUnit = DepthUnit.meters}) => testApp(
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith(
      (ref) => _TestSettingsNotifier(depthUnit: depthUnit),
    ),
  ],
  child: const SimplePlanDialog(),
);

void main() {
  testWidgets('quick plan takes depth and time as number boxes', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PlanNumberField), findsNWidgets(2));
    expect(_text(tester, 'Depth:'), '18');
    expect(_text(tester, 'Time:'), '45');
    expect(find.text('m'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
  });

  testWidgets('typed depth and time reach the created plan', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    await tester.enterText(_field('Depth:'), '25');
    await tester.enterText(_field('Time:'), '30');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(segments.any((s) => s.targetDepth == 25), isTrue);
    expect(
      segments.any((s) => s.targetDepth == 25 && s.durationSeconds == 30 * 60),
      isTrue,
    );
  });

  testWidgets('depth box works in the diver depth unit', (tester) async {
    await tester.pumpWidget(_harness(depthUnit: DepthUnit.feet));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    // 18 m seeded as whole feet.
    expect(_text(tester, 'Depth:'), '59');
    expect(find.text('ft'), findsOneWidget);

    await tester.enterText(_field('Depth:'), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(
      segments.map((s) => s.targetDepth),
      contains(closeTo(100 / 3.28084, 0.01)),
    );
  });

  testWidgets('refuses a depth outside the quick-plan band', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.enterText(_field('Depth:'), '80');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_field('Depth:')).decoration?.errorText,
      isNotNull,
    );
  });
}
