part of '../tripeaks_engine.dart';

MatchScoreState reduceMatchScore(
  MatchScoreState state,
  MatchScoreEvent event,
) {
  final result = tryReduceMatchScore(state, event);
  if (result.isSuccess) {
    return result.state;
  }
  throw StateError(result.error!.message);
}

/// Tries to reduce match-level score state by one scoring [event].
MatchScoreReduceResult tryReduceMatchScore(
  MatchScoreState state,
  MatchScoreEvent event,
) {
  switch (event) {
    case RoundScoreAggregated(
        playerId: final playerId,
        roundScore: final score
      ):
      final nextRoundScores = _addPlayerDelta(
        state.roundScoresByPlayer,
        playerId,
        score,
      );
      return MatchScoreReduceResult(
        state: state._copyWith(
          roundScoresByPlayer: nextRoundScores,
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );

    case FirstFinishBonusApplied(playerId: final playerId):
      if (state.firstFinishAwardedTo != null) {
        return MatchScoreReduceResult(
          state: state,
          error: MatchScoreError(
            code: MatchScoreErrorCode.firstFinishAlreadyAwarded,
            message: 'First-finish bonus already awarded to '
                '${state.firstFinishAwardedTo}.',
          ),
        );
      }
      final bonus = state.config.firstFinishBonus;
      final nextBonuses = _addPlayerDelta(
        state.multiplayerBonusesByPlayer,
        playerId,
        bonus,
      );
      return MatchScoreReduceResult(
        state: state._copyWith(
          multiplayerBonusesByPlayer: nextBonuses,
          firstFinishAwardedTo: playerId,
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );

    case RankingAdjustmentApplied(playerId: final playerId, rank: final rank):
      final adjustment = state.config.rankingAdjustments[rank] ?? 0;
      final nextAdjustments = _addPlayerDelta(
        state.competitiveAdjustmentsByPlayer,
        playerId,
        adjustment,
      );
      return MatchScoreReduceResult(
        state: state._copyWith(
          competitiveAdjustmentsByPlayer: nextAdjustments,
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );
  }
}

Map<String, int> _addPlayerDelta(
  Map<String, int> source,
  String playerId,
  int delta,
) {
  final next = Map<String, int>.from(source);
  next[playerId] = (next[playerId] ?? 0) + delta;
  return Map<String, int>.unmodifiable(next);
}

/// Convenience mutable wrapper around the pure reducer.
///
/// Prefer using [TriPeaksState] with [reduceTriPeaks] directly when you want
/// fully immutable, test-friendly state transitions.
