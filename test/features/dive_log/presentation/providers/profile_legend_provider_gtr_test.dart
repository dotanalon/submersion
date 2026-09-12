import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier([AppSettings? settings])
    : super(settings ?? const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(AppSettings settings) {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(profileLegendProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  group('ProfileLegend GTR', () {
    test('showGtr hydrates from the diver default', () {
      final container = containerWith(const AppSettings(defaultShowGtr: true));

      final state = container.read(profileLegendProvider);
      expect(state.showGtr, isTrue);
    });

    test('defaults to hidden', () {
      final container = containerWith(const AppSettings());

      final state = container.read(profileLegendProvider);
      expect(state.showGtr, isFalse);
    });

    test('toggleGtr flips visibility', () {
      final container = containerWith(const AppSettings());

      container.read(profileLegendProvider.notifier).toggleGtr();
      expect(container.read(profileLegendProvider).showGtr, isTrue);
      container.read(profileLegendProvider.notifier).toggleGtr();
      expect(container.read(profileLegendProvider).showGtr, isFalse);
    });

    test('showGtr counts as an active secondary toggle', () {
      const state = ProfileLegendState(
        showGtr: true,
        showCeiling: false,
        showDecoStops: false,
        showAscentRateColors: false,
        showEvents: false,
        showMaxDepthMarker: false,
        showPressureMarkers: false,
        showGasSwitchMarkers: false,
        showPhotoMarkers: false,
      );
      expect(state.activeSecondaryCount, 1);
    });
  });
}
