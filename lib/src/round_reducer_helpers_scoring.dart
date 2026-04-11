part of 'tripeaks_engine_internal.dart';

int _computeAppliedMultiplier(int currentStreak, ScoreConfig config) {
  final normalizedMax = config.multiplierMax < 1 ? 1 : config.multiplierMax;
  final normalizedStep = config.streakStepSize < 1 ? 1 : config.streakStepSize;
  final steps = currentStreak <= 0 ? 0 : (currentStreak ~/ normalizedStep);
  final raw = 1 + (steps * config.multiplierStepIncrement);
  final capped = min(raw, normalizedMax);
  return capped < 1 ? 1 : capped;
}

int _computeActiveMultiplier(
  ScoreConfig config,
  int preRemainingSeconds,
  int preStepCount,
  int preStreak,
) {
  if (config.multiplierMode == ScoreMultiplierMode.timeBonus) {
    if (preRemainingSeconds <= 0) {
      return 1;
    }
    final raw = 2 + preStepCount;
    return raw < 1 ? 1 : raw;
  }
  return _computeAppliedMultiplier(preStreak, config);
}

int _computeEffectiveTableauBasePoints(ScoreConfig config, int roundNumber) {
  var effective = config.pointsTableauToWaste;
  final growthBps = config.roundBasePointsGrowthBps;
  if (growthBps == 0 || roundNumber <= 1) {
    return effective;
  }
  final factor = 10000 + growthBps;
  final targetRound = roundNumber < 1 ? 1 : roundNumber;
  for (var i = 2; i <= targetRound; i++) {
    effective = (effective * factor) ~/ 10000;
  }
  return effective;
}

TimeBonusTimerState _onTimeBonusAdvanced(
  TimeBonusTimerState state,
  ScoreConfig config, {
  required int nextStepCount,
}) {
  if (config.multiplierMode != ScoreMultiplierMode.timeBonus) {
    return state;
  }
  final added =
      config.timeBonusSecondsPerMove < 0 ? 0 : config.timeBonusSecondsPerMove;
  final maxSeconds =
      config.timeBonusMaxSeconds < 0 ? 0 : config.timeBonusMaxSeconds;
  final nextSeconds = min(maxSeconds, state.remainingSeconds + added);
  final needsNewToken = state.remainingSeconds == 0 && nextSeconds > 0;
  return state.copyWith(
    remainingSeconds: nextSeconds,
    deadlineToken:
        needsNewToken ? state.deadlineToken + 1 : state.deadlineToken,
    stepCount: nextStepCount < 0 ? 0 : nextStepCount,
  );
}

TimeBonusTimerState _onTimeBonusResetOnDraw(
  TimeBonusTimerState state,
  ScoreConfig config,
) {
  if (config.multiplierMode != ScoreMultiplierMode.timeBonus) {
    return state;
  }
  if (state.remainingSeconds == 0) {
    if (state.stepCount == 0) {
      return state;
    }
    return state.copyWith(stepCount: 0);
  }
  return state.copyWith(
    remainingSeconds: 0,
    deadlineToken: state.deadlineToken + 1,
    stepCount: 0,
  );
}

TimeBonusTimerState _onTimeBonusExpired(
  TimeBonusTimerState state,
  ScoreConfig config,
) {
  if (config.multiplierMode != ScoreMultiplierMode.timeBonus) {
    return state;
  }
  return state.copyWith(remainingSeconds: 0, stepCount: 0);
}

ScoreDeltaBreakdown _buildDrawBreakdown(int drawPoints) {
  return ScoreDeltaBreakdown(
    tableauBasePoints: 0,
    multiplierExtraPoints: 0,
    peakBonusPoints: 0,
    drawPoints: drawPoints,
    invalidPenaltyPoints: 0,
    endRoundRemainingStockBonusPoints: 0,
    appliedMultiplier: 1,
    totalDelta: drawPoints,
  );
}

ScoreDeltaBreakdown _buildInvalidPenaltyBreakdown(int penalty) {
  return ScoreDeltaBreakdown(
    tableauBasePoints: 0,
    multiplierExtraPoints: 0,
    peakBonusPoints: 0,
    drawPoints: 0,
    invalidPenaltyPoints: penalty,
    endRoundRemainingStockBonusPoints: 0,
    appliedMultiplier: 1,
    totalDelta: penalty,
  );
}

({int newlyClearedCount, int nextAwardedMask}) _computePeakClearBonus(
  List<bool> removed,
  int awardedMask,
) {
  var newlyClearedCount = 0;
  var nextMask = awardedMask;

  for (var peakId = 0;
      peakId < TriPeaksState._peakDefinitions.length;
      peakId++) {
    final alreadyAwarded = ((nextMask >> peakId) & 1) == 1;
    if (alreadyAwarded) {
      continue;
    }
    final peakSlots = TriPeaksState._peakDefinitions[peakId];
    final isCleared = peakSlots.every((index) => removed[index]);
    if (!isCleared) {
      continue;
    }
    nextMask |= (1 << peakId);
    newlyClearedCount++;
  }

  return (
    newlyClearedCount: newlyClearedCount,
    nextAwardedMask: nextMask,
  );
}

List<_TriPeaksSnapshot> _pushUndoSnapshot(TriPeaksState state) {
  if (!state.undoConfig.enabled || state.undoConfig.maxSteps == 0) {
    return state._undoHistory;
  }

  final next = <_TriPeaksSnapshot>[
    ...state._undoHistory,
    state._toSnapshot(),
  ];
  final overflow = next.length - state.undoConfig.maxSteps;
  if (overflow > 0) {
    return next.sublist(overflow);
  }
  return next;
}

TriPeaksState _applyGapResetIfNeeded(TriPeaksState state, int tick) {
  final config = state.streakConfig;
  if (!config.enabled || config.maxGapTicks == null) {
    return state;
  }
  final lastTick = state.streakState.lastActionTick;
  if (lastTick == null) {
    return state;
  }
  if (tick - lastTick > config.maxGapTicks!) {
    final nextStreakState = state.streakState.copyWith(currentStreak: 0);
    final nextStrikeTimer = _onStreakEndedStrikeTimer(
      state.strikeTimerState,
      state.strikeTimerConfig,
    );
    final nextBonusSlotsState = _withRecomputedOpenSlots(
      state.bonusSlotsState,
      state.bonusSlotsConfig,
      nextStreakState,
    );
    return state._copyWith(
      streakState: nextStreakState,
      strikeTimerState: nextStrikeTimer,
      bonusSlotsState: nextBonusSlotsState,
    );
  }
  return state;
}
