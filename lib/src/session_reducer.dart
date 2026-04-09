part of '../tripeaks_engine.dart';

/// Reduces a multi-round session [state] by [action], throwing on failures.
TriPeaksSessionState reduceTriPeaksSession(
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  final result = tryReduceTriPeaksSession(state, action, tick: tick);
  if (result.isSuccess) {
    return result.state;
  }
  if (result.sessionError case final sessionError?) {
    throw StateError(sessionError.message);
  }
  throw StateError(result.roundError!.message);
}

/// Tries to reduce a multi-round session without throwing.
TriPeaksSessionReduceResult tryReduceTriPeaksSession(
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  if (state.isSessionFinished) {
    return TriPeaksSessionReduceResult(
      state: state,
      sessionError: const TriPeaksSessionError(
        code: TriPeaksSessionErrorCode.gameAlreadyFinished,
        message: 'Session is already finished.',
      ),
    );
  }

  switch (action) {
    case PlayRoundAction(action: final roundAction):
      if (state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundAlreadyFinished,
            message: 'Current round is finished. Start next round to continue.',
          ),
        );
      }

      final roundResult = tryReduceTriPeaks(
        state.currentRound,
        roundAction,
        tick: tick,
      );
      if (!roundResult.isSuccess) {
        final nextState = identical(roundResult.state, state.currentRound)
            ? state
            : state._copyWith(currentRound: roundResult.state);
        return TriPeaksSessionReduceResult(
          state: nextState,
          roundError: roundResult.error,
        );
      }

      final nextRound = roundResult.state;
      if (!nextRound.isFinished) {
        return TriPeaksSessionReduceResult(
          state: state._copyWith(currentRound: nextRound),
        );
      }

      final completed = state.roundsCompleted + 1;
      final won = state.roundsWon + (nextRound.isWon ? 1 : 0);
      final lost = state.roundsLost + (nextRound.isLost ? 1 : 0);
      final timedOut = state.roundsTimedOut + (nextRound.isTimedOut ? 1 : 0);
      final result = RoundResult(
        roundNumber: state.currentRoundNumber,
        outcome: nextRound.isWon
            ? RoundOutcome.won
            : nextRound.isLost
                ? RoundOutcome.lost
                : RoundOutcome.timedOut,
        finalScore: nextRound.scoreState.totalScore,
      );
      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRound: nextRound,
          roundsCompleted: completed,
          roundsWon: won,
          roundsLost: lost,
          roundsTimedOut: timedOut,
          roundResults: <RoundResult>[...state.roundResults, result],
        ),
      );

    case StartNextRoundAction():
      if (!state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundNotFinished,
            message: 'Current round is not finished yet.',
          ),
        );
      }
      if (!state._hasNextRound) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.alreadyOnLastRound,
            message: 'No next round is available.',
          ),
        );
      }
      final nextRoundNumber = state.currentRoundNumber + 1;
      final nextRound = TriPeaksSessionState._buildRoundState(
        roundNumber: nextRoundNumber,
        seed: state.seed,
        roundDecks: state.roundDecks,
        scoreConfig: state.scoreConfig,
        roundRulesConfig: state.roundRulesConfig,
        roundTimerConfig: state.roundTimerConfig,
        undoConfig: state.undoConfig,
        streakConfig: state.streakConfig,
        strikeTimerConfig: state.strikeTimerConfig,
        bonusSlotsConfig: state.bonusSlotsConfig,
      );
      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRoundNumber: nextRoundNumber,
          currentRound: nextRound,
        ),
      );

    case AbortRoundAction(reason: final reason):
      if (state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundAlreadyFinished,
            message: 'Current round is finished. Start next round to continue.',
          ),
        );
      }

      final abortReason = reason ?? AbortReason.userSkip;
      final completed = state.roundsCompleted + 1;
      final aborted = state.roundsAborted + 1;
      final result = RoundResult(
        roundNumber: state.currentRoundNumber,
        outcome: RoundOutcome.aborted,
        abortReason: abortReason,
        finalScore: state.currentRound.scoreState.totalScore,
      );

      if (!state._hasNextRound) {
        return TriPeaksSessionReduceResult(
          state: state._copyWith(
            roundsCompleted: completed,
            roundsAborted: aborted,
            roundResults: <RoundResult>[...state.roundResults, result],
          ),
        );
      }

      final nextRoundNumber = state.currentRoundNumber + 1;
      final nextRound = TriPeaksSessionState._buildRoundState(
        roundNumber: nextRoundNumber,
        seed: state.seed,
        roundDecks: state.roundDecks,
        scoreConfig: state.scoreConfig,
        roundRulesConfig: state.roundRulesConfig,
        roundTimerConfig: state.roundTimerConfig,
        undoConfig: state.undoConfig,
        streakConfig: state.streakConfig,
        strikeTimerConfig: state.strikeTimerConfig,
        bonusSlotsConfig: state.bonusSlotsConfig,
      );

      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRoundNumber: nextRoundNumber,
          roundsCompleted: completed,
          roundsAborted: aborted,
          roundResults: <RoundResult>[...state.roundResults, result],
          currentRound: nextRound,
        ),
      );
  }
}
