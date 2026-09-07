import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Samples at or deeper than this fraction of max depth are still the
/// working part of the dive; deco can only be counted after the last of
/// them. Matches the cut the dive-to-plan converter applies.
const double _workingLevelFraction = 0.5;

/// A sample-to-sample rate slower than this (m/min) counts as holding a stop
/// rather than travelling between stops.
const double _holdRateMetersPerMinute = 1.5;

/// Seconds the diver spent holding decompression stops on a logged dive:
/// time after the last working-depth sample during which a stop obligation
/// existed ([decoStopCurve] above zero) and the depth was essentially
/// constant. Travel between stops is excluded, the same way the planner's
/// deco time counts stop durations but not the legs between them.
///
/// [decoStopCurve] is indexed like [profile]; a shorter curve is treated as
/// having no obligation beyond its end.
int loggedDecoSeconds({
  required List<DiveProfilePoint> profile,
  required List<double> decoStopCurve,
}) {
  if (profile.length < 2 || decoStopCurve.isEmpty) return 0;

  final sorted = [...profile]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final maxDepth = sorted.fold(0.0, (m, p) => math.max(m, p.depth));
  if (maxDepth <= 0) return 0;

  final threshold = maxDepth * _workingLevelFraction;
  var workingEnd = 0;
  for (var i = sorted.length - 1; i >= 0; i--) {
    if (sorted[i].depth >= threshold) {
      workingEnd = i;
      break;
    }
  }

  var seconds = 0;
  for (var i = workingEnd + 1; i < sorted.length; i++) {
    final obligation = i < decoStopCurve.length ? decoStopCurve[i] : 0.0;
    if (obligation <= 0) continue;
    final dt = sorted[i].timestamp - sorted[i - 1].timestamp;
    if (dt <= 0) continue;
    final rate = (sorted[i].depth - sorted[i - 1].depth).abs() / (dt / 60.0);
    if (rate < _holdRateMetersPerMinute) seconds += dt;
  }
  return seconds;
}
