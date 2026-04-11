part of 'tripeaks_engine_internal.dart';

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
