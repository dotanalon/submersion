import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';

/// Builds a profile at 10 s steps from (seconds, depth) corner points.
List<DiveProfilePoint> _profile(List<(int, double)> corners) {
  final points = <DiveProfilePoint>[];
  for (var i = 0; i < corners.length - 1; i++) {
    final (t0, d0) = corners[i];
    final (t1, d1) = corners[i + 1];
    for (var t = t0; t < t1; t += 10) {
      final f = (t - t0) / (t1 - t0);
      points.add(DiveProfilePoint(timestamp: t, depth: d0 + (d1 - d0) * f));
    }
  }
  final (tl, dl) = corners.last;
  points.add(DiveProfilePoint(timestamp: tl, depth: dl));
  return points;
}

void main() {
  // 40 m for 20 min, up to 6 m, 10 min stop, up to 3 m, 15 min stop, surface.
  final profile = _profile([
    (0, 0),
    (120, 40),
    (1320, 40),
    (1560, 6),
    (2160, 6),
    (2220, 3),
    (3120, 3),
    (3180, 0),
  ]);

  test('counts time held at stops while a stop obligation exists', () {
    // Obligation from mid-bottom until just before surfacing.
    final stops = [
      for (final p in profile)
        p.timestamp >= 600 && p.timestamp < 3150 ? 3.0 : 0.0,
    ];
    final seconds = loggedDecoSeconds(profile: profile, decoStopCurve: stops);
    // The two stops, 600 s + 900 s, within a little slack for the ramps.
    expect(seconds, closeTo(1500, 60));
  });

  test('bottom time never counts as deco even under an obligation', () {
    final stops = [for (final _ in profile) 3.0];
    final seconds = loggedDecoSeconds(profile: profile, decoStopCurve: stops);
    expect(seconds, lessThan(1600));
  });

  test('no obligation means no deco time', () {
    final stops = [for (final _ in profile) 0.0];
    expect(loggedDecoSeconds(profile: profile, decoStopCurve: stops), 0);
  });

  test('mismatched or empty curves are tolerated', () {
    expect(loggedDecoSeconds(profile: profile, decoStopCurve: const []), 0);
    expect(loggedDecoSeconds(profile: const [], decoStopCurve: const []), 0);
  });
}
