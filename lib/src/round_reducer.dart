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
    return TriPeaksReduceResult(
      state: preprocessed._copyWith(
        scoreState: preprocessed.scoreState.applyDelta(
          penalty,
          appliedMultiplier: 1,
          breakdown: breakdown,
        ),
        streakState: nextStreakState,
        strikeTimerState: nextStrikeTimerState,
        bonusSlotsState: nextBonusSlotsState,
      ),
      scoreDelta: penalty,
      scoreBreakdown: breakdown,
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

    case RemoveTableauCardAction(
        index: final index,
        targetSlot: final targetSlot
      ):
      final nextHistory = _pushUndoSnapshot(state);
      final nextRemoved = state.removed.toList(growable: false);
      nextRemoved[index] = true;
      final peakBonus = _computePeakClearBonus(
        nextRemoved,
        state.clearedPeaksAwardedMask,
      );
      final appliedMultiplier = _computeActiveMultiplier(state);
      final tableauBasePoints = state.scoreConfig.pointsTableauToWaste;
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
      final nextTimeBonus = _onTimeBonusAdvanced(
        state.timeBonusTimerState,
        state.scoreConfig,
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
      );
      return (
        state: state._copyWith(
          removed: nextRemoved,
          scoreState: state.scoreState.applyDelta(
            delta,
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

    case UseBonusSlotAction(slotIndex: final slotIndex):
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

    case StrikeTimerExpiredAction():
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

    case UndoAction():
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

    case TimeBonusExpiredAction():
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
}

int _computeAppliedMultiplier(int currentStreak, ScoreConfig config) {
  final normalizedMax = config.multiplierMax < 1 ? 1 : config.multiplierMax;
  final normalizedStep = config.streakStepSize < 1 ? 1 : config.streakStepSize;
  final steps = currentStreak <= 0 ? 0 : (currentStreak ~/ normalizedStep);
  final raw = 1 + (steps * config.multiplierStepIncrement);
  final capped = min(raw, normalizedMax);
  return capped < 1 ? 1 : capped;
}

int _computeActiveMultiplier(TriPeaksState state) {
  if (state.scoreConfig.multiplierMode == ScoreMultiplierMode.timeBonus) {
    if (state.timeBonusTimerState.remainingSeconds <= 0) {
      return 1;
    }
    final raw = state.scoreConfig.timeBonusMultiplier;
    return raw < 1 ? 1 : raw;
  }
  final preStreak = state.streakState.currentStreak;
  return _computeAppliedMultiplier(preStreak, state.scoreConfig);
}

TimeBonusTimerState _onTimeBonusAdvanced(
  TimeBonusTimerState state,
  ScoreConfig config,
) {
  if (config.multiplierMode != ScoreMultiplierMode.timeBonus) {
    return state;
  }
  final added = config.timeBonusSecondsPerMove;
  final maxSeconds =
      config.timeBonusMaxSeconds < 0 ? 0 : config.timeBonusMaxSeconds;
  final nextSeconds = min(maxSeconds, state.remainingSeconds + added);
  final needsNewToken = state.remainingSeconds == 0 && nextSeconds > 0;
  return state.copyWith(
    remainingSeconds: nextSeconds,
    deadlineToken:
        needsNewToken ? state.deadlineToken + 1 : state.deadlineToken,
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
    return state;
  }
  return state.copyWith(
    remainingSeconds: 0,
    deadlineToken: state.deadlineToken + 1,
  );
}

TimeBonusTimerState _onTimeBonusExpired(
  TimeBonusTimerState state,
  ScoreConfig config,
) {
  if (config.multiplierMode != ScoreMultiplierMode.timeBonus) {
    return state;
  }
  return state.copyWith(remainingSeconds: 0);
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

BonusSlotsState _withRecomputedOpenSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  final openSlotsCount = _computeOpenSlotsCount(streakState, config);
  return _withOpenSlotsCount(state, openSlotsCount);
}

({BonusSlotsState bonusSlotsState, int nextSpawnNonce})
    _withRecomputedOpenSlotsAndSpawn(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
  Rank? lastSuccessfulTableauRank,
  int roundSeed,
  int spawnNonce,
) {
  final openSlotsCount = _computeOpenSlotsCount(streakState, config);
  if (openSlotsCount <= state.openSlotsCount) {
    return (
      bonusSlotsState: _withOpenSlotsCount(state, openSlotsCount),
      nextSpawnNonce: spawnNonce,
    );
  }

  final nextSlots = <List<Card>>[
    List<Card>.from(state.slots[0]),
    List<Card>.from(state.slots[1]),
    List<Card>.from(state.slots[2]),
  ];

  var nextSpawnNonce = spawnNonce;
  for (var slotIndex = state.openSlotsCount + 1;
      slotIndex <= openSlotsCount;
      slotIndex++) {
    if (nextSlots[slotIndex - 1].isEmpty) {
      nextSlots[slotIndex - 1].add(
        _spawnOpenSlotAnchor(
          config,
          lastSuccessfulTableauRank,
          roundSeed: roundSeed,
          spawnNonce: nextSpawnNonce,
          slotIndex: slotIndex,
        ),
      );
      nextSpawnNonce++;
    }
  }

  return (
    bonusSlotsState: state.copyWith(
      openSlotsCount: openSlotsCount,
      slots: List<List<Card>>.unmodifiable(
        nextSlots.map((slot) => List<Card>.unmodifiable(slot)).toList(),
      ),
    ),
    nextSpawnNonce: nextSpawnNonce,
  );
}

BonusSlotsState _onDrawBonusSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  if (!config.enabled) {
    return _withOpenSlotsCount(state, 1);
  }
  if (config.closeOnDraw) {
    return _withOpenSlotsCount(
      state,
      _computeOpenSlotsCount(streakState, config),
    );
  }
  return _withRecomputedOpenSlots(state, config, streakState);
}

BonusSlotsState _onInvalidActionBonusSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  if (!config.enabled) {
    return _withOpenSlotsCount(state, 1);
  }
  if (config.closeOnInvalidAction) {
    return _withOpenSlotsCount(
      state,
      _computeOpenSlotsCount(streakState, config),
    );
  }
  return _withRecomputedOpenSlots(state, config, streakState);
}

BonusSlotsState _withOpenSlotsCount(BonusSlotsState state, int openSlotsCount) {
  if (openSlotsCount >= state.openSlotsCount) {
    return state.copyWith(openSlotsCount: openSlotsCount);
  }
  final merged = <List<Card>>[
    List<Card>.from(state.slots[0]),
    List<Card>.from(state.slots[1]),
    List<Card>.from(state.slots[2]),
  ];
  final movedToSlot1Bottom = <Card>[];
  for (var slot = openSlotsCount + 1; slot <= 3; slot++) {
    final from = merged[slot - 1];
    if (from.isEmpty) {
      continue;
    }
    for (final card in from) {
      if (!card.isJoker) {
        movedToSlot1Bottom.add(card);
      }
    }
    merged[slot - 1] = <Card>[];
  }
  if (movedToSlot1Bottom.isNotEmpty) {
    merged[0] = <Card>[
      ...movedToSlot1Bottom,
      ...merged[0],
    ];
  }
  return state.copyWith(
    openSlotsCount: openSlotsCount,
    slots: List<List<Card>>.unmodifiable(
      merged.map((slot) => List<Card>.unmodifiable(slot)).toList(),
    ),
  );
}

List<List<Card>> _appendCardToSlot(
  List<List<Card>> slots,
  int slotIndex,
  Card card,
) {
  final next = <List<Card>>[
    List<Card>.from(slots[0]),
    List<Card>.from(slots[1]),
    List<Card>.from(slots[2]),
  ];
  next[slotIndex - 1].add(card);
  return List<List<Card>>.unmodifiable(
    next.map((slot) => List<Card>.unmodifiable(slot)).toList(),
  );
}

List<List<Card>> _appendTableauCardToSlot(
  List<List<Card>> slots,
  int slotIndex,
  Card card,
  BonusSlotsConfig config,
) {
  var next = _appendCardToSlot(slots, slotIndex, card);
  final slot = next[slotIndex - 1];
  final previousTop = slot.length >= 2 ? slot[slot.length - 2] : null;
  final shouldConsumePreviousTop = previousTop != null &&
      ((previousTop.isJoker && config.jokerConsumedOnFirstUse) ||
          previousTop.isAnchor);
  if (slot.length >= 2 && shouldConsumePreviousTop) {
    final mutable = <List<Card>>[
      List<Card>.from(next[0]),
      List<Card>.from(next[1]),
      List<Card>.from(next[2]),
    ];
    mutable[slotIndex - 1].removeAt(mutable[slotIndex - 1].length - 2);
    next = List<List<Card>>.unmodifiable(
      mutable.map((s) => List<Card>.unmodifiable(s)).toList(),
    );
  }
  return next;
}

Card _spawnOpenSlotAnchor(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank, {
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
}) {
  switch (config.spawnPolicy) {
    case BonusSlotSpawnPolicy.joker:
      return const Card.joker();
    case BonusSlotSpawnPolicy.tierFixedRank:
      return Card.anchor(
        _tierFixedAnchorRank(config, lastSuccessfulRank),
      );
    case BonusSlotSpawnPolicy.tierRandomRank:
      return Card.anchor(
        _tierRandomAnchorRank(
          config,
          lastSuccessfulRank,
          roundSeed: roundSeed,
          spawnNonce: spawnNonce,
          slotIndex: slotIndex,
        ),
      );
  }
}

Rank _tierFixedAnchorRank(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank,
) {
  final tier = _tierForLastSuccessfulRank(
    lastSuccessfulRank,
    config.defaultAnchorTierWhenUnknown,
  );
  switch (tier) {
    case BonusSlotAnchorTier.low:
      return config.lowTierAnchorRank;
    case BonusSlotAnchorTier.high:
      return config.highTierAnchorRank;
  }
}

const List<Rank> _lowTierAnchorRanks = <Rank>[
  Rank.two,
  Rank.three,
  Rank.four,
  Rank.five,
  Rank.six,
  Rank.seven,
  Rank.eight,
  Rank.nine,
  Rank.ten,
];

const List<Rank> _highTierAnchorRanks = <Rank>[
  Rank.ace,
  Rank.jack,
  Rank.queen,
  Rank.king,
];

const int _tierMixLow = 1;
const int _tierMixHigh = 2;

Rank _tierRandomAnchorRank(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank, {
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
}) {
  final tier = _tierForLastSuccessfulRank(
    lastSuccessfulRank,
    config.defaultAnchorTierWhenUnknown,
  );
  final (tierDiscriminator, domain) = switch (tier) {
    BonusSlotAnchorTier.low => (_tierMixLow, _lowTierAnchorRanks),
    BonusSlotAnchorTier.high => (_tierMixHigh, _highTierAnchorRanks),
  };
  final index = _deterministicIndex(
    roundSeed: roundSeed,
    spawnNonce: spawnNonce,
    slotIndex: slotIndex,
    tierDiscriminator: tierDiscriminator,
    domainSize: domain.length,
  );
  return domain[index];
}

int _deterministicIndex({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required int tierDiscriminator,
  required int domainSize,
}) {
  var x = 0x9e3779b9;
  x ^= roundSeed;
  x = _mix32(x + 0x85ebca6b);
  x ^= (spawnNonce + 1) * 0x27d4eb2d;
  x = _mix32(x);
  x ^= slotIndex * 0x165667b1;
  x = _mix32(x + (tierDiscriminator * 0x9e3779b1));
  return (x & 0x7fffffff) % domainSize;
}

int _mix32(int value) {
  var x = value & 0xffffffff;
  x ^= (x >> 16);
  x = (x * 0x7feb352d) & 0xffffffff;
  x ^= (x >> 15);
  x = (x * 0x846ca68b) & 0xffffffff;
  x ^= (x >> 16);
  return x & 0xffffffff;
}

BonusSlotAnchorTier _tierForLastSuccessfulRank(
  Rank? lastSuccessfulRank,
  BonusSlotAnchorTier whenUnknown,
) {
  final rank = lastSuccessfulRank;
  if (rank == null) {
    return whenUnknown;
  }
  if (rank.value >= 2 && rank.value <= 10) {
    return BonusSlotAnchorTier.low;
  }
  return BonusSlotAnchorTier.high;
}

int _resolveTargetSlotForDraw(TriPeaksState state, int? targetSlot) {
  // Draw actions always target slot 1.
  return 1;
}

int _resolveTargetSlotForTableauMove(
  TriPeaksState state,
  int index,
  int? targetSlot,
) {
  if (targetSlot case final explicit?) {
    return explicit;
  }
  for (var slot = 1; slot <= state.bonusSlotsState.openSlotsCount; slot++) {
    if (state.canRemoveTableau(index, targetSlot: slot)) {
      return slot;
    }
  }
  return 1;
}

int _computeOpenSlotsCount(
  StreakState streakState,
  BonusSlotsConfig config,
) {
  if (!config.enabled) {
    return 1;
  }

  var open = 1;
  if (streakState.currentStreak >= config.spawnOnOpenSlot2AtStreak) {
    open = 2;
  }
  if (streakState.currentStreak >= config.spawnOnOpenSlot3AtStreak) {
    open = 3;
  }
  if (open < 1) {
    return 1;
  }
  if (open > config.maxSlots) {
    return config.maxSlots;
  }
  return open;
}

StreakState _onSuccessfulDraw(StreakState streak, StreakConfig config) {
  if (!config.enabled) {
    return streak;
  }
  if (config.resetOnDraw) {
    return streak.copyWith(currentStreak: 0);
  }
  return streak;
}

StreakState _onSuccessfulTableauMove(
  StreakState streak,
  StreakConfig config,
  int tick,
) {
  if (!config.enabled) {
    return streak;
  }
  final current = streak.currentStreak + 1;
  final best = current > streak.bestStreak ? current : streak.bestStreak;
  return streak.copyWith(
    currentStreak: current,
    bestStreak: best,
    lastActionTick: tick,
  );
}

StrikeTimerState _onStreakAdvancedStrikeTimer(
  StrikeTimerState state,
  StrikeTimerConfig config,
) {
  if (!config.enabled) {
    return state.copyWith(isArmed: false);
  }
  return state.copyWith(
    isArmed: true,
    deadlineToken: state.deadlineToken + 1,
  );
}

StrikeTimerState _onStreakEndedStrikeTimer(
  StrikeTimerState state,
  StrikeTimerConfig config,
) {
  if (!config.enabled) {
    return state.copyWith(isArmed: false);
  }
  return state.copyWith(isArmed: false);
}

/// Reduces a multi-round session by applying one [action].
