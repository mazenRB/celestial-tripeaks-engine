part of 'tripeaks_engine_internal.dart';

/// Deterministically compares independent completed runs.
CompetitionComparisonResult compareCompletedRuns(
  Map<String, CompletedSessionResult> runs, {
  CompetitionRankingConfig config = const CompetitionRankingConfig(),
}) {
  final entries = runs.entries.toList(growable: false)
    ..sort((left, right) => _compareCompletedRuns(left, right, config));

  final rankings = <RankedRunResult>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final run = entry.value;
    final placement = i + 1;
    rankings.add(
      RankedRunResult(
        placement: placement,
        entryId: entry.key,
        run: run,
        breakdown: RunComparisonBreakdown(
          baseScore: run.finalScore,
          completionBonus: run.status == CompletedRunStatus.completed
              ? config.completionBonus
              : 0,
          placementBonus: config.placementBonuses[placement] ?? 0,
        ),
      ),
    );
  }
  return CompetitionComparisonResult(rankings: rankings);
}

int _compareCompletedRuns(
  MapEntry<String, CompletedSessionResult> left,
  MapEntry<String, CompletedSessionResult> right,
  CompetitionRankingConfig config,
) {
  final leftRun = left.value;
  final rightRun = right.value;
  switch (config.tieBreakerPolicy) {
    case CompetitionTieBreakerPolicy.score:
      final scoreCmp = rightRun.finalScore.compareTo(leftRun.finalScore);
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      return left.key.compareTo(right.key);

    case CompetitionTieBreakerPolicy.winsThenScore:
      final winsCmp = rightRun.roundsWon.compareTo(leftRun.roundsWon);
      if (winsCmp != 0) {
        return winsCmp;
      }
      final scoreCmp = rightRun.finalScore.compareTo(leftRun.finalScore);
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      return left.key.compareTo(right.key);

    case CompetitionTieBreakerPolicy.scoreThenFingerprint:
      final scoreCmp = rightRun.finalScore.compareTo(leftRun.finalScore);
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      final fingerprintCmp =
          leftRun.finalFingerprint.compareTo(rightRun.finalFingerprint);
      if (fingerprintCmp != 0) {
        return fingerprintCmp;
      }
      return left.key.compareTo(right.key);
  }
}
