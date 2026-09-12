import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

void main() {
  test('deco stop legend state defaults to visible', () {
    const state = ProfileLegendState();
    expect(state.showDecoStops, isTrue);
  });

  test('copyWith toggles deco stops without touching the ceiling', () {
    const state = ProfileLegendState();
    final updated = state.copyWith(showDecoStops: false);

    expect(updated.showDecoStops, isFalse);
    expect(updated.showCeiling, state.showCeiling);
  });

  test('equality accounts for the deco stop field', () {
    const state = ProfileLegendState();
    expect(state.copyWith(showDecoStops: false) == state, isFalse);
  });
}
