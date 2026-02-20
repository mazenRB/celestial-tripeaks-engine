part of '../tripeaks_engine.dart';

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
        error.code == TriPeaksErrorCode.nothingToUndo) {
      return TriPeaksReduceResult(
        state: preprocessed,
        scoreDelta: 0,
        error: error,
      );
    }
    final penalty = preprocessed.scoreConfig.penaltyInvalidAction;
    var nextStreakState = preprocessed.streakState;
    if (preprocessed.streakConfig.enabled &&
        preprocessed.streakConfig.resetOnInvalidAction) {
      nextStreakState = nextStreakState.copyWith(currentStreak: 0);
    }
    return TriPeaksReduceResult(
      state: preprocessed._copyWith(
        scoreState: preprocessed.scoreState.applyDelta(penalty),
        streakState: nextStreakState,
      ),
      scoreDelta: penalty,
      error: error,
    );
  }

  final applied = _applyAction(
    preprocessed,
    action,
    effectiveTick: effectiveTick,
  );
  return TriPeaksReduceResult(
    state: applied.state,
    scoreDelta: applied.scoreDelta,
  );
}

({TriPeaksState state, int scoreDelta}) _applyAction(
  TriPeaksState state,
  TriPeaksAction action, {
  required int effectiveTick,
}) {
  switch (action) {
    case DrawFromStockAction():
      final delta = state.scoreConfig.pointsDrawFromStock;
      final nextHistory = _pushUndoSnapshot(state);
      final nextStreak = _onSuccessfulDraw(
        state.streakState,
        state.streakConfig,
      );
      return (
        state: state._copyWith(
          waste: <Card>[...state.waste, state.stock.first],
          stock: state.stock.skip(1).toList(growable: false),
          scoreState: state.scoreState.applyDelta(delta),
          streakState: nextStreak,
          undoHistory: nextHistory,
        ),
        scoreDelta: delta,
      );

    case RemoveTableauCardAction(index: final index):
      final delta = state.scoreConfig.pointsTableauToWaste;
      final nextHistory = _pushUndoSnapshot(state);
      final nextRemoved = state.removed.toList(growable: false);
      nextRemoved[index] = true;
      final nextStreak = _onSuccessfulTableauMove(
        state.streakState,
        state.streakConfig,
        effectiveTick,
      );
      return (
        state: state._copyWith(
          removed: nextRemoved,
          waste: <Card>[...state.waste, state.tableau[index]],
          scoreState: state.scoreState.applyDelta(delta),
          streakState: nextStreak,
          undoHistory: nextHistory,
        ),
        scoreDelta: delta,
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
      );
  }
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
    return state._copyWith(
      streakState: state.streakState.copyWith(currentStreak: 0),
    );
  }
  return state;
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

/// Reduces a multi-round session by applying one [action].
