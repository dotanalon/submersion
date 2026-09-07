import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Seconds the source dive spent holding deco stops, for the plan-vs-actual
/// strip; null when the plan has no source dive or the profile could not be
/// analysed.
final sourceDiveDecoSecondsProvider = FutureProvider<int?>((ref) async {
  final dive = await ref.watch(sourceDiveForPlanProvider.future);
  if (dive == null || dive.profile.isEmpty) return null;
  final analysis = await ref.watch(profileAnalysisProvider(dive.id).future);
  if (analysis == null) return null;
  return loggedDecoSeconds(
    profile: dive.profile,
    decoStopCurve: analysis.decoStopCurve,
  );
});
