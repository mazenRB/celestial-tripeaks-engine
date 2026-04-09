part of '../tripeaks_engine.dart';

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyStartRoundTimerAction(TriPeaksState state) {
  final nextHistory = _pushUndoSnapshot(state);
  final nextRoundTimer = state.roundTimerState.copyWith(
    isStarted: true,
    deadlineToken: state.roundTimerState.deadlineToken + 1,
  );
  const breakdown = ScoreDeltaBreakdown.zero;
  return (
    state: state._copyWith(
      roundTimerState: nextRoundTimer,
      scoreState: state.scoreState.withNoScoreChange(
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      undoHistory: nextHistory,
    ),
    scoreDelta: 0,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyAdvanceRoundTimerAction(
  TriPeaksState state, {
  required int elapsedSeconds,
}) {
  final nextHistory = _pushUndoSnapshot(state);
  final nextRemaining = max(
    0,
    state.roundTimerState.remainingSeconds - elapsedSeconds,
  );
  final nextRoundTimer = state.roundTimerState.copyWith(
    remainingSeconds: nextRemaining,
    deadlineToken: state.roundTimerState.deadlineToken + 1,
  );
  const breakdown = ScoreDeltaBreakdown.zero;
  return (
    state: state._copyWith(
      roundStatus:
          nextRemaining == 0 ? RoundStatus.timedOut : state.roundStatus,
      roundTimerState: nextRoundTimer,
      scoreState: state.scoreState.withNoScoreChange(
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      undoHistory: nextHistory,
    ),
    scoreDelta: 0,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyDrawFromStockAction(
  TriPeaksState state, {
  required int? targetSlot,
}) {
  final nextTimeBonus = _onTimeBonusResetOnDraw(
    state.timeBonusTimerState,
    state.scoreConfig,
  );
  final delta = state.scoreConfig.pointsDrawFromStock;
  final breakdown = _buildDrawBreakdown(delta);
  final nextHistory = _pushUndoSnapshot(state);
  final nextStreak = _onSuccessfulDraw(
    state.streakState,
    state.streakConfig,
  );
  final nextStrikeTimer = _onStreakEndedStrikeTimer(
    state.strikeTimerState,
    state.strikeTimerConfig,
  );
  final selectedSlot = _resolveTargetSlotForDraw(state, targetSlot);
  final drawnCard = state.stock.first;
  final nextSlots = _appendCardToSlot(
    state.bonusSlotsState.slots,
    selectedSlot,
    drawnCard,
  );
  final nextBonusSlotsState = _onDrawBonusSlots(
    state.bonusSlotsState.copyWith(slots: nextSlots),
    state.bonusSlotsConfig,
    nextStreak,
  );
  return (
    state: state._copyWith(
      stock: state.stock.skip(1).toList(growable: false),
      scoreState: state.scoreState.applyDelta(
        delta,
        allowNegativeTotalScore: state.scoreConfig.allowNegativeTotalScore,
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      streakState: nextStreak,
      strikeTimerState: nextStrikeTimer,
      timeBonusTimerState: nextTimeBonus,
      bonusSlotsState: nextBonusSlotsState,
      undoHistory: nextHistory,
    ),
    scoreDelta: delta,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyRemoveTableauCardAction(
  TriPeaksState state, {
  required int index,
  required int? targetSlot,
  required int effectiveTick,
}) {
  final nextHistory = _pushUndoSnapshot(state);
  final nextRemoved = state.removed.toList(growable: false);
  nextRemoved[index] = true;
  final peakBonus = _computePeakClearBonus(
    nextRemoved,
    state.clearedPeaksAwardedMask,
  );
  final preTimeRemaining = state.timeBonusTimerState.remainingSeconds;
  final preTimeStepCount = state.timeBonusTimerState.stepCount;
  final appliedMultiplier = _computeActiveMultiplier(
    state.scoreConfig,
    preTimeRemaining,
    preTimeStepCount,
    state.streakState.currentStreak,
  );
  final tableauBasePoints = _computeEffectiveTableauBasePoints(
    state.scoreConfig,
    state.roundNumber,
  );
  final multiplierExtraPoints = tableauBasePoints * (appliedMultiplier - 1);
  final peakBonusPoints =
      state.scoreConfig.pointsPeakCleared * peakBonus.newlyClearedCount;
  final delta = tableauBasePoints + multiplierExtraPoints + peakBonusPoints;
  final breakdown = ScoreDeltaBreakdown(
    tableauBasePoints: tableauBasePoints,
    multiplierExtraPoints: multiplierExtraPoints,
    peakBonusPoints: peakBonusPoints,
    drawPoints: 0,
    invalidPenaltyPoints: 0,
    endRoundRemainingStockBonusPoints: 0,
    appliedMultiplier: appliedMultiplier,
    totalDelta: delta,
  );
  final nextStreak = _onSuccessfulTableauMove(
    state.streakState,
    state.streakConfig,
    effectiveTick,
  );
  final nextStepCount = preTimeRemaining > 0 ? preTimeStepCount + 1 : 0;
  final nextTimeBonus = _onTimeBonusAdvanced(
    state.timeBonusTimerState,
    state.scoreConfig,
    nextStepCount: nextStepCount,
  );
  final nextStrikeTimer = _onStreakAdvancedStrikeTimer(
    state.strikeTimerState,
    state.strikeTimerConfig,
  );
  final selectedSlot = _resolveTargetSlotForTableauMove(
    state,
    index,
    targetSlot,
  );
  final nextSlots = _appendTableauCardToSlot(
    state.bonusSlotsState.slots,
    selectedSlot,
    state.tableau[index],
    state.bonusSlotsConfig,
  );
  final spawnResult = _withRecomputedOpenSlotsAndSpawn(
    state.bonusSlotsState.copyWith(slots: nextSlots),
    state.bonusSlotsConfig,
    nextStreak,
    state.tableau[index].rank,
    state.roundSeed,
    state.bonusAnchorSpawnNonce,
    state.stock,
  );
  return (
    state: state._copyWith(
      removed: nextRemoved,
      stock: spawnResult.stock,
      scoreState: state.scoreState.applyDelta(
        delta,
        allowNegativeTotalScore: state.scoreConfig.allowNegativeTotalScore,
        appliedMultiplier: appliedMultiplier,
        breakdown: breakdown,
      ),
      streakState: nextStreak,
      strikeTimerState: nextStrikeTimer,
      timeBonusTimerState: nextTimeBonus,
      bonusSlotsState: spawnResult.bonusSlotsState,
      lastSuccessfulTableauRank: state.tableau[index].rank,
      clearedPeaksAwardedMask: peakBonus.nextAwardedMask,
      bonusAnchorSpawnNonce: spawnResult.nextSpawnNonce,
      undoHistory: nextHistory,
    ),
    scoreDelta: delta,
    scoreBreakdown: breakdown,
    appliedMultiplier: appliedMultiplier,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyUseBonusSlotAction(
  TriPeaksState state, {
  required int slotIndex,
}) {
  final nextHistory = _pushUndoSnapshot(state);
  final nextBonusSlotsState = state.bonusSlotsState.copyWith(
    lastUsedSlot: slotIndex,
  );
  const breakdown = ScoreDeltaBreakdown.zero;
  return (
    state: state._copyWith(
      scoreState: state.scoreState.withNoScoreChange(
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      bonusSlotsState: nextBonusSlotsState,
      undoHistory: nextHistory,
    ),
    scoreDelta: 0,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyStrikeTimerExpiredAction(TriPeaksState state) {
  final nextHistory = _pushUndoSnapshot(state);
  if (state.scoreConfig.multiplierMode == ScoreMultiplierMode.timeBonus) {
    const breakdown = ScoreDeltaBreakdown.zero;
    return (
      state: state._copyWith(undoHistory: nextHistory),
      scoreDelta: 0,
      scoreBreakdown: breakdown,
      appliedMultiplier: 1,
    );
  }
  final endedStreak = state.streakState.copyWith(currentStreak: 0);
  final nextStrikeTimer = _onStreakEndedStrikeTimer(
    state.strikeTimerState,
    state.strikeTimerConfig,
  );
  final nextBonusSlotsState = _withOpenSlotsCount(state.bonusSlotsState, 1);
  const breakdown = ScoreDeltaBreakdown.zero;
  return (
    state: state._copyWith(
      scoreState: state.scoreState.withNoScoreChange(
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      streakState: endedStreak,
      strikeTimerState: nextStrikeTimer,
      bonusSlotsState: nextBonusSlotsState,
      undoHistory: nextHistory,
    ),
    scoreDelta: 0,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyUndoAction(TriPeaksState state) {
  final snapshot = state._undoHistory.last;
  final remaining = state._undoHistory
      .take(state._undoHistory.length - 1)
      .toList(growable: false);
  final restored = state._restoreFromSnapshot(snapshot);
  return (
    state: restored._copyWith(undoHistory: remaining),
    scoreDelta: 0,
    scoreBreakdown: restored.scoreState.lastBreakdown,
    appliedMultiplier: restored.scoreState.currentMultiplier,
  );
}

({
  TriPeaksState state,
  int scoreDelta,
  ScoreDeltaBreakdown scoreBreakdown,
  int appliedMultiplier,
}) _applyTimeBonusExpiredAction(TriPeaksState state) {
  final nextHistory = _pushUndoSnapshot(state);
  final nextTimeBonus = _onTimeBonusExpired(
    state.timeBonusTimerState,
    state.scoreConfig,
  );
  const breakdown = ScoreDeltaBreakdown.zero;
  return (
    state: state._copyWith(
      scoreState: state.scoreState.withNoScoreChange(
        appliedMultiplier: 1,
        breakdown: breakdown,
      ),
      timeBonusTimerState: nextTimeBonus,
      undoHistory: nextHistory,
    ),
    scoreDelta: 0,
    scoreBreakdown: breakdown,
    appliedMultiplier: 1,
  );
}
