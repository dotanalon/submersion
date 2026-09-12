import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';

void main() {
  group('ProfileRightAxisMetric.gtr', () {
    test('is a gas-analysis metric measured in minutes', () {
      const gtr = ProfileRightAxisMetric.gtr;
      expect(gtr.category, ProfileMetricCategory.gasAnalysis);
      expect(gtr.unitSuffix, 'min');
      expect(gtr.shortName, 'GTR');
      expect(gtr.color, isNotNull);
    });

    test('is not in the automatic fallback chain', () {
      // Fallbacks are for metrics nearly every dive has; GTR needs an
      // air-integrated pressure track.
      expect(
        ProfileRightAxisMetric.fallbackPriority,
        isNot(contains(ProfileRightAxisMetric.gtr)),
      );
    });
  });

  group('ProfileRightAxisMetric.ascentRate', () {
    test('has expected display metadata', () {
      const metric = ProfileRightAxisMetric.ascentRate;
      expect(metric.displayName, 'Ascent Rate');
      expect(metric.shortName, 'Rate');
      expect(metric.category, ProfileMetricCategory.primary);
    });

    test('is excluded from the auto fallback chain', () {
      // Ascent rate must never auto-claim the right axis; it is opt-in only.
      expect(
        ProfileRightAxisMetric.fallbackPriority,
        isNot(contains(ProfileRightAxisMetric.ascentRate)),
      );
    });
  });

  group('ProfileRightAxisMetric.o2CellMv', () {
    test('is a gas-analysis metric measured in millivolts', () {
      const metric = ProfileRightAxisMetric.o2CellMv;
      expect(metric.category, ProfileMetricCategory.gasAnalysis);
      expect(metric.unitSuffix, 'mV');
      expect(metric.displayName, isNotEmpty);
      expect(metric.shortName, isNotEmpty);
    });

    test('is excluded from the auto fallback chain', () {
      // Diagnostic metric: joining the chain would auto-select it on CCR dives
      // whenever the preferred metric has no data.
      expect(
        ProfileRightAxisMetric.fallbackPriority,
        isNot(contains(ProfileRightAxisMetric.o2CellMv)),
      );
    });

    test('appears in the gas analysis category listing', () {
      expect(
        ProfileMetricCategory.gasAnalysis.metrics,
        contains(ProfileRightAxisMetric.o2CellMv),
      );
    });
  });
}
