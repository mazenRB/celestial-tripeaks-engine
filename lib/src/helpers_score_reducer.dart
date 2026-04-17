part of 'tripeaks_engine_internal.dart';

/// Reduces [state] by [event], throwing when the event is invalid.
CompetitionScoreState reduceCompetitionScore(
  CompetitionScoreState state,
  CompetitionScoreEvent event,
) {
  final result = tryReduceCompetitionScore(state, event);
  if (result.isSuccess) {
    return result.state;
  }
  throw StateError(result.error!.message);
}

/// Tries to reduce competition helper score state by one [event].
CompetitionScoreReduceResult tryReduceCompetitionScore(
  CompetitionScoreState state,
  CompetitionScoreEvent event,
) {
  switch (event) {
    case RunScoreRecorded(entryId: final entryId, runScore: final runScore):
      final nextRunScores =
          _addEntryDelta(state.runScoresByEntry, entryId, runScore);
      return CompetitionScoreReduceResult(
        state: state._copyWith(
          runScoresByEntry: nextRunScores,
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );

    case BonusApplied(entryId: final entryId):
      if (state.completionBonusAwardedTo.contains(entryId)) {
        return CompetitionScoreReduceResult(
          state: state,
          error: CompetitionScoreError(
            code: CompetitionScoreErrorCode.completionBonusAlreadyAwarded,
            message: 'Completion bonus already awarded to $entryId.',
          ),
        );
      }
      final nextBonuses = _addEntryDelta(
          state.bonusesByEntry, entryId, state.config.completionBonus);
      return CompetitionScoreReduceResult(
        state: state._copyWith(
          bonusesByEntry: nextBonuses,
          completionBonusAwardedTo: <String>{
            ...state.completionBonusAwardedTo,
            entryId,
          },
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );

    case PlacementAdjustmentApplied(entryId: final entryId, rank: final rank):
      final adjustment = state.config.placementAdjustments[rank] ?? 0;
      final nextAdjustments = _addEntryDelta(
        state.placementAdjustmentsByEntry,
        entryId,
        adjustment,
      );
      return CompetitionScoreReduceResult(
        state: state._copyWith(
          placementAdjustmentsByEntry: nextAdjustments,
          processedEventsCount: state.processedEventsCount + 1,
        ),
      );
  }
}

Map<String, int> _addEntryDelta(
  Map<String, int> source,
  String entryId,
  int delta,
) {
  final next = Map<String, int>.from(source);
  next[entryId] = (next[entryId] ?? 0) + delta;
  return Map<String, int>.unmodifiable(next);
}
