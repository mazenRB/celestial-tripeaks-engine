part of '../tripeaks_engine.dart';

/// Appends a replay entry from one attempted [action] and [result].
ReplaySession recordAttempt(
  ReplaySession replay,
  TriPeaksSessionAction action,
  TriPeaksSessionReduceResult result, {
  int? tick,
}) {
  final sequence = replay.entries.length + 1;
  final entryTick = tick ?? sequence;
  final accepted = _isAcceptedResult(result);
  final entry = ReplayEntry(
    sequence: sequence,
    action: ReplayActionDto.fromSessionAction(action),
    accepted: accepted,
    tick: entryTick,
    failureReason: accepted ? null : _mapFailureReason(result),
  );
  return replay._copyWith(entries: <ReplayEntry>[...replay.entries, entry]);
}

/// Applies one attempted [action], then records that attempt into [replay].
ReplayRecordResult recordAction(
  ReplaySession replay,
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  final reduceResult = tryReduceTriPeaksSession(state, action, tick: tick);
  final nextReplay = recordAttempt(
    replay,
    action,
    reduceResult,
    tick: tick,
  );
  return ReplayRecordResult(
    replay: nextReplay,
    state: reduceResult.state,
    reduceResult: reduceResult,
  );
}

/// Rebuilds final session state by replaying accepted entries only.
TriPeaksSessionState replayToState(ReplaySession replay) {
  return replayStep(replay, replay.entries.length);
}

/// Rebuilds state after first [count] replay entries.
///
/// Only entries with `accepted=true` are applied.
TriPeaksSessionState replayStep(ReplaySession replay, int count) {
  if (count < 0 || count > replay.entries.length) {
    throw RangeError.range(count, 0, replay.entries.length, 'count');
  }

  var state = TriPeaksSessionState.newSession(
    ruleset: replay.ruleset,
    seed: replay.seed,
    scoreConfig: replay.scoreConfig,
    roundRulesConfig: replay.roundRulesConfig,
    undoConfig: replay.undoConfig,
    streakConfig: replay.streakConfig,
    strikeTimerConfig: replay.strikeTimerConfig,
    bonusSlotsConfig: replay.bonusSlotsConfig,
  );

  final ordered = replay.entries.take(count).toList(growable: false)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));

  for (final entry in ordered) {
    if (!entry.accepted) {
      continue;
    }
    final result = tryReduceTriPeaksSession(
      state,
      entry.action.toSessionAction(),
      tick: entry.tick,
    );
    state = result.state;
  }

  return state;
}

bool _isAcceptedResult(TriPeaksSessionReduceResult result) {
  if (result.isSuccess) {
    return true;
  }
  if (result.roundError case TriPeaksRuleError(code: final code)) {
    switch (code) {
      case TriPeaksErrorCode.invalidTableauIndex:
      case TriPeaksErrorCode.tableauCardNotRemovable:
      case TriPeaksErrorCode.emptyStock:
        return true;
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
        return false;
    }
  }
  return false;
}

ReplayFailureReason _mapFailureReason(TriPeaksSessionReduceResult result) {
  if (result.sessionError case TriPeaksSessionError(code: final code)) {
    switch (code) {
      case TriPeaksSessionErrorCode.gameAlreadyFinished:
        return ReplayFailureReason.gameAlreadyFinished;
      case TriPeaksSessionErrorCode.roundAlreadyFinished:
        return ReplayFailureReason.roundAlreadyFinished;
      case TriPeaksSessionErrorCode.roundNotFinished:
        return ReplayFailureReason.roundNotFinished;
      case TriPeaksSessionErrorCode.alreadyOnLastRound:
        return ReplayFailureReason.alreadyOnLastRound;
    }
  }
  if (result.roundError case TriPeaksRuleError(code: final code)) {
    switch (code) {
      case TriPeaksErrorCode.undoDisabled:
        return ReplayFailureReason.undoDisabled;
      case TriPeaksErrorCode.nothingToUndo:
        return ReplayFailureReason.nothingToUndo;
      case TriPeaksErrorCode.strikeTimerDisabled:
        return ReplayFailureReason.strikeTimerDisabled;
      case TriPeaksErrorCode.strikeTimerNotArmed:
        return ReplayFailureReason.strikeTimerNotArmed;
      case TriPeaksErrorCode.staleStrikeTimerExpiry:
        return ReplayFailureReason.staleStrikeTimerExpiry;
      case TriPeaksErrorCode.timeBonusTimerDisabled:
        return ReplayFailureReason.timeBonusTimerDisabled;
      case TriPeaksErrorCode.timeBonusTimerNotArmed:
        return ReplayFailureReason.timeBonusTimerNotArmed;
      case TriPeaksErrorCode.staleTimeBonusExpiry:
        return ReplayFailureReason.staleTimeBonusExpiry;
      case TriPeaksErrorCode.invalidTableauIndex:
      case TriPeaksErrorCode.tableauCardNotRemovable:
      case TriPeaksErrorCode.emptyStock:
      case TriPeaksErrorCode.invalidBonusSlotIndex:
      case TriPeaksErrorCode.bonusSlotClosed:
        break;
    }
  }
  return ReplayFailureReason.roundAlreadyFinished;
}
