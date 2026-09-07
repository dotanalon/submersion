import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

PlanSegment _travel(String id, double from, double to, int order) =>
    PlanSegment.travel(
      id: id,
      fromDepth: from,
      targetDepth: to,
      tankId: 'tank-1',
      gasMix: _air,
      ratePerMinute: 9.0,
      order: order,
    );

PlanSegment _hold(String id, double depth, int minutes, int order) =>
    PlanSegment.hold(
      id: id,
      depth: depth,
      durationMinutes: minutes,
      tankId: 'tank-1',
      gasMix: _air,
      order: order,
    );

domain.DivePlan _plan(List<PlanSegment> segments) => domain.DivePlan(
  id: 'plan-1',
  name: 'Authored stops',
  gfLow: 40,
  gfHigh: 80,
  lastStopDepth: 3.0,
  segments: segments,
  tanks: const [_airTank],
  createdAt: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
);

void main() {
  group('PlanEngine with authored stops after the bottom', () {
    final bottomOnly = _plan([_travel('d', 0, 45, 0), _hold('b', 45, 25, 1)]);
    final withStops = _plan([
      _travel('d', 0, 45, 0),
      _hold('b', 45, 25, 1),
      _travel('a1', 45, 9, 2),
      _hold('s1', 9, 15, 3),
      _travel('a2', 9, 6, 4),
      _hold('s2', 6, 30, 5),
    ]);

    test('TTS at bottom is the planned time from bottom to surface', () {
      final outcome = const PlanEngine().compute(withStops);
      final bottomEnd = outcome.segmentOutcomes
          .firstWhere((s) => s.segmentId == 'b')
          .endRuntime;
      expect(outcome.ttsAtBottom, outcome.runtimeSeconds - bottomEnd);
      // Longer than a direct ascent would be: the authored stops are longer
      // than what the model would have scheduled.
      final direct = const PlanEngine().compute(bottomOnly);
      expect(outcome.ttsAtBottom, greaterThan(direct.ttsAtBottom));
    });

    test(
      'TTS starts where the final ascent begins, not at the deepest leg',
      () {
        // Bottom at 45 m, then a wander to 40 m before the ascent starts.
        final wander = _plan([
          _travel('d', 0, 45, 0),
          _hold('b', 45, 20, 1),
          _travel('w1', 45, 40, 2),
          _hold('w2', 40, 5, 3),
          _travel('a1', 40, 9, 4),
          _hold('s1', 9, 15, 5),
        ]);
        final outcome = const PlanEngine().compute(wander);
        final wanderEnd = outcome.segmentOutcomes
            .firstWhere((s) => s.segmentId == 'w2')
            .endRuntime;
        expect(outcome.ttsAtBottom, outcome.runtimeSeconds - wanderEnd);
      },
    );

    test('TTS from a shallower final working level, not the deepest leg', () {
      final twoLevels = _plan([
        _travel('d', 0, 45, 0),
        _hold('b', 45, 20, 1),
        _travel('u', 45, 30, 2),
        _hold('l2', 30, 10, 3),
      ]);
      final outcome = const PlanEngine().compute(twoLevels);
      final levelEnd = outcome.segmentOutcomes
          .firstWhere((s) => s.segmentId == 'l2')
          .endRuntime;
      expect(outcome.ttsAtBottom, outcome.runtimeSeconds - levelEnd);
      final direct = const PlanEngine().compute(
        _plan([_travel('d', 0, 45, 0), _hold('b', 45, 20, 1)]),
      );
      expect(outcome.ttsAtBottom, isNot(direct.ttsAtBottom));
    });

    test('a plan without authored stops keeps the scheduled TTS', () {
      final outcome = const PlanEngine().compute(bottomOnly);
      final bottomEnd = outcome.segmentOutcomes
          .firstWhere((s) => s.segmentId == 'b')
          .endRuntime;
      expect(outcome.ttsAtBottom, outcome.runtimeSeconds - bottomEnd);
    });

    test('deco time counts authored stop holds plus computed stops', () {
      final outcome = const PlanEngine().compute(withStops);
      final computed = outcome.stops.fold(
        0,
        (sum, s) => sum + s.durationSeconds,
      );
      expect(outcome.totalDecoSeconds, (15 + 30) * 60 + computed);
    });
  });
}
