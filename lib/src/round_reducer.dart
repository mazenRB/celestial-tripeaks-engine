part of '../tripeaks_engine.dart';

/// Reduces [state] by [action], throwing on invalid actions.
TriPeaksState reduceTriPeaks(
  TriPeaksState state,
  TriPeaksAction action, {
  int? tick,
}) {
  final result = tryReduceTriPeaks(
    state,
    action,
    tick: tick,
  );
  if (!result.isSuccess) {
    final error = result.error!;
    switch (error.code) {
      case TriPeaksErrorCode.invalidTableauIndex:
        if (action case RemoveTableauCardAction(index: final index)) {
          throw RangeError.index(index, state.tableau, 'index');
        }
        throw StateError(error.message);

      case TriPeaksErrorCode.tableauCardNotRemovable:
      case TriPeaksErrorCode.emptyStock:
      case TriPeaksErrorCode.undoDisabled:
      case TriPeaksErrorCode.nothingToUndo:
      case TriPeaksErrorCode.invalidBonusSlotIndex:
      case TriPeaksErrorCode.bonusSlotClosed:
      case TriPeaksErrorCode.strikeTimerDisabled:
      case TriPeaksErrorCode.strikeTimerNotArmed:
      case TriPeaksErrorCode.staleStrikeTimerExpiry:
      case TriPeaksErrorCode.timeBonusTimerDisabled:
      case TriPeaksErrorCode.timeBonusTimerNotArmed:
      case TriPeaksErrorCode.staleTimeBonusExpiry:
        throw StateError(error.message);
    }
  }

  return result.state;
}

/// Tries to reduce [state] by one [action] without throwing.
///
/// On invalid actions, this returns the original state with a typed error.
TriPeaksReduceResult tryReduceTriPeaks(
  TriPeaksState state,
  TriPeaksAction action, {
  int? tick,
}) {
  final effectiveTick = tick ?? (state.scoreState.movesCount + 1);
  final preprocessed = _applyGapResetIfNeeded(state, effectiveTick);
  final error = _validateAction(preprocessed, action);
  if (error != null) {
    if (error.code == TriPeaksErrorCode.undoDisabled ||
        error.code == TriPeaksErrorCode.nothingToUndo ||
        error.code == TriPeaksErrorCode.strikeTimerDisabled ||
        error.code == TriPeaksErrorCode.strikeTimerNotArmed ||
        error.code == TriPeaksErrorCode.staleStrikeTimerExpiry ||
        error.code == TriPeaksErrorCode.timeBonusTimerDisabled ||
        error.code == TriPeaksErrorCode.timeBonusTimerNotArmed ||
        error.code == TriPeaksErrorCode.staleTimeBonusExpiry) {
      return TriPeaksReduceResult(
        state: preprocessed,
        scoreDelta: 0,
        scoreBreakdown: preprocessed.scoreState.lastBreakdown,
        appliedMultiplier: preprocessed.scoreState.currentMultiplier,
        error: error,
      );
    }
    final penalty = preprocessed.scoreConfig.penaltyInvalidAction;
    final breakdown = _buildInvalidPenaltyBreakdown(penalty);
    var nextStreakState = preprocessed.streakState;
    var nextStrikeTimerState = preprocessed.strikeTimerState;
    if (preprocessed.streakConfig.enabled &&
        preprocessed.streakConfig.resetOnInvalidAction) {
      nextStreakState = nextStreakState.copyWith(currentStreak: 0);
      nextStrikeTimerState = _onStreakEndedStrikeTimer(
        preprocessed.strikeTimerState,
        preprocessed.strikeTimerConfig,
      );
    }
    final nextBonusSlotsState = _onInvalidActionBonusSlots(
      preprocessed.bonusSlotsState,
      preprocessed.bonusSlotsConfig,
      nextStreakState,
    );
    final nextScoreState = preprocessed.scoreState.applyDelta(
      penalty,
      allowNegativeTotalScore: preprocessed.scoreConfig.allowNegativeTotalScore,
      appliedMultiplier: 1,
      breakdown: breakdown,
    );
    return TriPeaksReduceResult(
      state: preprocessed._copyWith(
        scoreState: nextScoreState,
        streakState: nextStreakState,
        strikeTimerState: nextStrikeTimerState,
        bonusSlotsState: nextBonusSlotsState,
      ),
      scoreDelta: nextScoreState.lastDelta,
      scoreBreakdown: nextScoreState.lastBreakdown,
      appliedMultiplier: 1,
      error: error,
    );
  }

  final preWon = preprocessed.isWon;
  final applied = _applyAction(
    preprocessed,
    action,
    effectiveTick: effectiveTick,
  );
  final postWon = applied.state.isWon;
  if (!preWon && postWon) {
    final bonus = applied.state.stock.length *
        applied.state.scoreConfig.pointsPerRemainingStockCardOnWin;
    if (bonus != 0) {
      final breakdown = ScoreDeltaBreakdown(
        tableauBasePoints: applied.scoreBreakdown.tableauBasePoints,
        multiplierExtraPoints: applied.scoreBreakdown.multiplierExtraPoints,
        peakBonusPoints: applied.scoreBreakdown.peakBonusPoints,
        drawPoints: applied.scoreBreakdown.drawPoints,
        invalidPenaltyPoints: applied.scoreBreakdown.invalidPenaltyPoints,
        endRoundRemainingStockBonusPoints: bonus,
        appliedMultiplier: applied.scoreBreakdown.appliedMultiplier,
        totalDelta: applied.scoreBreakdown.totalDelta + bonus,
      );
      final nextScoreState = applied.state.scoreState.applyDelta(
        bonus,
        allowNegativeTotalScore:
            applied.state.scoreConfig.allowNegativeTotalScore,
        appliedMultiplier: applied.appliedMultiplier,
        breakdown: breakdown,
      );
      final nextState = applied.state._copyWith(scoreState: nextScoreState);
      return TriPeaksReduceResult(
        state: nextState,
        scoreDelta: applied.scoreDelta + bonus,
        scoreBreakdown: breakdown,
        appliedMultiplier: applied.appliedMultiplier,
      );
    }
  }
  return TriPeaksReduceResult(
    state: applied.state,
    scoreDelta: applied.scoreDelta,
    scoreBreakdown: applied.scoreBreakdown,
    appliedMultiplier: applied.appliedMultiplier,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyAction(
  TriPeaksState state,
  TriPeaksAction action, {
  required int effectiveTick,
}) {
  switch (action) {
    case DrawFromStockAction(targetSlot: final targetSlot):
      return _applyDrawFromStockAction(state, targetSlot: targetSlot);

    case RemoveTableauCardAction(
        index: final index,
        targetSlot: final targetSlot
      ):
      return _applyRemoveTableauCardAction(
        state,
        index: index,
        targetSlot: targetSlot,
        effectiveTick: effectiveTick,
      );

    case UseBonusSlotAction(slotIndex: final slotIndex):
      return _applyUseBonusSlotAction(state, slotIndex: slotIndex);

    case StrikeTimerExpiredAction():
      return _applyStrikeTimerExpiredAction(state);

    case UndoAction():
      return _applyUndoAction(state);

    case TimeBonusExpiredAction():
      return _applyTimeBonusExpiredAction(state);
  }
}
