import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

ProfileAnalysis _analysis({
  required List<double> ceilingCurve,
  required List<double> decoStopCurve,
  List<int> ndlCurve = const [],
  List<int>? ttsCurve,
  List<double>? cnsCurve,
  List<int?>? gtrCurve,
}) {
  return ProfileAnalysis(
    ascentRates: const [],
    ascentRateStats: const AscentRateStats(
      maxAscentRate: 0,
      maxDescentRate: 0,
      averageAscentRate: 0,
      averageDescentRate: 0,
      violationCount: 0,
      criticalViolationCount: 0,
      timeInViolation: 0,
    ),
    ascentRateViolations: const [],
    events: const [],
    ceilingCurve: ceilingCurve,
    ndlCurve: ndlCurve,
    ttsCurve: ttsCurve,
    cnsCurve: cnsCurve,
    gtrCurve: gtrCurve,
    decoStatuses: const [],
    o2Exposure: const O2Exposure(otu: 0),
    ppO2Curve: const [],
    decoStopCurve: decoStopCurve,
    maxDepth: 0,
    averageDepth: 0,
    maxDepthTimestamp: 0,
    durationSeconds: 0,
  );
}

/// v208 retired the per-metric Computer/Calculated preference and settled on
/// the calculated curve for every decompression metric. The computer's own
/// readings are still stored on each sample -- these guard that they no longer
/// steer any curve, so one Buhlmann model with the diver's own gradient
/// factors produces every number, comparably across a whole logbook and across
/// a computer swap partway through it.
void main() {
  group('computer readings never steer the calculated curves', () {
    test('the deco stop band keeps the quantized calculated curve', () {
      // 4.5 m is a legitimate non-3m stop on some computers. Before v208 the
      // band showed it verbatim; now the quantized calculated curve stands.
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 30, ceiling: 4.5),
        const DiveProfilePoint(timestamp: 10, depth: 30, ceiling: 3.0),
      ];

      final result = overlayRebreatherSensorData(
        _analysis(ceilingCurve: [4.2, 2.1], decoStopCurve: [6.0, 3.0]),
        profile,
      );

      expect(result.decoStopCurve, [6.0, 3.0]);
    });

    test('the ceiling line keeps the exact continuous calculated curve', () {
      // Unchanged from #755: computers only ever log a stepped stop depth.
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 30, ceiling: 4.5),
        const DiveProfilePoint(timestamp: 10, depth: 30, ceiling: 4.5),
      ];

      final result = overlayRebreatherSensorData(
        _analysis(ceilingCurve: [4.2, 4.2], decoStopCurve: [6.0, 6.0]),
        profile,
      );

      expect(result.ceilingCurve, [4.2, 4.2]);
    });

    test('NDL, TTS, CNS and GTR keep their calculated curves', () {
      final profile = [
        const DiveProfilePoint(
          timestamp: 0,
          depth: 30,
          ndl: 12,
          tts: 20,
          cns: 44.0,
          rbt: 900,
        ),
        const DiveProfilePoint(
          timestamp: 10,
          depth: 30,
          ndl: 11,
          tts: 21,
          cns: 45.0,
          rbt: 840,
        ),
      ];

      final result = overlayRebreatherSensorData(
        _analysis(
          ceilingCurve: const [0.0, 0.0],
          decoStopCurve: const [0.0, 0.0],
          ndlCurve: const [30, 29],
          ttsCurve: const [3, 3],
          cnsCurve: const [2.0, 2.5],
          gtrCurve: const [3600, 3540],
        ),
        profile,
      );

      expect(result.ndlCurve, [30, 29]);
      expect(result.ttsCurve, [3, 3]);
      expect(result.cnsCurve, [2.0, 2.5]);
      expect(result.gtrCurve, [3600, 3540]);
    });

    test('an open-circuit profile comes back untouched', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 30, ndl: 12, ceiling: 4.5),
        const DiveProfilePoint(timestamp: 10, depth: 30, ndl: 11, ceiling: 3.0),
      ];
      final base = _analysis(
        ceilingCurve: const [4.2, 2.1],
        decoStopCurve: const [6.0, 3.0],
      );

      expect(overlayRebreatherSensorData(base, profile), same(base));
    });
  });
}
