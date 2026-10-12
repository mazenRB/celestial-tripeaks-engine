import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

import 'multiplayer_config.dart';
import 'multiplayer_events.dart';
import 'multiplayer_player_state.dart';
import 'multiplayer_state.dart';

/// Applies a match event and throws when the event is not valid.
MatchState reduceMatch(MatchState state, MatchEvent event) {
  final result = tryReduceMatch(state, event);
  if (!result.isSuccess) throw StateError(result.failure!.message);
  return result.state;
}

/// Reapplies an ordered sequence of events from a deterministic match state.
MatchState replayMatchEvents(MatchState initial, List<MatchEvent> events) {
  var state = initial;
  for (final event in events) {
    state = reduceMatch(state, event);
  }
  return state;
}

/// Applies a match event without throwing on invalid input.
MatchReduceResult tryReduceMatch(MatchState state, MatchEvent event) {
  if (state.phase == MatchPhase.finished) {
    return _failure(
      state,
      MatchReduceFailureCode.matchAlreadyFinished,
      'Match is already finished.',
    );
  }
  return switch (event) {
    SubmitMatchActionEvent() => _submitPlayerAction(state, event),
    VoteToSkipLiveIntermissionEvent() => _voteToSkip(state, event),
    AdvanceLiveIntermissionEvent() => _advanceLiveTimer(state, event),
    AdvanceAsyncDeadlineEvent() => _advanceAsyncDeadline(state, event),
    WithdrawFromAsyncMatchEvent() => _withdraw(state, event),
  };
}

MatchReduceResult _submitPlayerAction(
  MatchState state,
  SubmitMatchActionEvent event,
) {
  if (state.phase != MatchPhase.playing) {
    return _failure(
      state,
      MatchReduceFailureCode.wrongMatchPhase,
      'Player actions are accepted only while the match is playing.',
    );
  }
  final index = state.players.indexWhere(
    (player) => player.playerId == event.playerId,
  );
  if (index < 0) {
    return _failure(
      state,
      MatchReduceFailureCode.playerNotFound,
      'Player is not part of this match.',
    );
  }
  final player = state.players[index];
  if (player.withdrawn ||
      player.session.isSessionFinished ||
      (state.config.matchMode == MatchMode.live &&
          player.session.roundsCompleted >= state.currentRoundNumber)) {
    return _failure(
      state,
      MatchReduceFailureCode.playerAlreadyFinished,
      'Player has already completed the current play segment.',
    );
  }
  final recorded = recordAction(player.replay, player.session, event.action);
  if (!recorded.reduceResult.isSuccess) {
    return _failure(
      state,
      MatchReduceFailureCode.actionRejected,
      recorded.reduceResult.sessionError?.message ??
          recorded.reduceResult.roundError?.message ??
          'Engine rejected the player action.',
    );
  }
  final players = state.players.toList();
  players[index] = MatchPlayerState(
    playerId: player.playerId,
    session: recorded.state,
    replay: recorded.replay,
  );
  final updated = copyMatchStateForReducer(state, players);
  if (state.config.matchMode == MatchMode.asynchronous) {
    if (updated.players.every((entry) => entry.session.isSessionFinished)) {
      return MatchReduceResult(
        state: updated.copyWith(
          phase: MatchPhase.finished,
          clearAsyncDeadline: true,
        ),
      );
    }
    return MatchReduceResult(state: updated);
  }
  if (!updated.players.every(
    (entry) => entry.session.roundsCompleted >= state.currentRoundNumber,
  )) {
    return MatchReduceResult(state: updated);
  }
  if (state.currentRoundNumber == state.config.ruleset.roundsPerGame &&
      updated.players.every((entry) => entry.session.isSessionFinished)) {
    return MatchReduceResult(
      state: updated.copyWith(phase: MatchPhase.finished),
    );
  }
  return MatchReduceResult(
    state: updated.copyWith(
      phase: MatchPhase.intermission,
      intermissionRemainingSeconds: updated.config.intermissionDurationSeconds,
      intermissionDeadlineToken: updated.intermissionDeadlineToken + 1,
      skipVotes: const <String>{},
    ),
  );
}

MatchReduceResult _voteToSkip(
  MatchState state,
  VoteToSkipLiveIntermissionEvent event,
) {
  if (state.config.matchMode != MatchMode.live ||
      state.phase != MatchPhase.intermission) {
    return _failure(
      state,
      MatchReduceFailureCode.wrongMatchPhase,
      'Skip votes are accepted only during a live intermission.',
    );
  }
  if (!state.config.playerIds.contains(event.playerId)) {
    return _failure(
      state,
      MatchReduceFailureCode.playerNotFound,
      'Player is not part of this match.',
    );
  }
  if (state.skipVotes.contains(event.playerId)) {
    return _failure(
      state,
      MatchReduceFailureCode.duplicateSkipVote,
      'Player has already voted to skip this intermission.',
    );
  }
  final votes = <String>{...state.skipVotes, event.playerId};
  final requiredVotes =
      (state.players.length * state.config.skipVoteThreshold).ceil();
  if (votes.length >= requiredVotes) {
    return _advanceRound(state.copyWith(skipVotes: votes));
  }
  return MatchReduceResult(state: state.copyWith(skipVotes: votes));
}

MatchReduceResult _advanceLiveTimer(
  MatchState state,
  AdvanceLiveIntermissionEvent event,
) {
  if (state.config.matchMode != MatchMode.live ||
      state.phase != MatchPhase.intermission) {
    return _failure(
      state,
      MatchReduceFailureCode.wrongMatchPhase,
      'Intermission timer can advance only during a live intermission.',
    );
  }
  if (event.deadlineToken != state.intermissionDeadlineToken) {
    return _failure(
      state,
      MatchReduceFailureCode.staleTimer,
      'Intermission timer token is stale.',
    );
  }
  if (event.elapsedSeconds <= 0) {
    return _failure(
      state,
      MatchReduceFailureCode.invalidElapsedSeconds,
      'Elapsed seconds must be positive.',
    );
  }
  final remaining = state.intermissionRemainingSeconds - event.elapsedSeconds;
  if (remaining <= 0) return _advanceRound(state);
  return MatchReduceResult(
    state: state.copyWith(
      intermissionRemainingSeconds: remaining,
      intermissionDeadlineToken: state.intermissionDeadlineToken + 1,
    ),
  );
}

MatchReduceResult _advanceAsyncDeadline(
  MatchState state,
  AdvanceAsyncDeadlineEvent event,
) {
  if (state.config.matchMode != MatchMode.asynchronous ||
      state.asyncDeadlineRemainingSeconds == null) {
    return _failure(
      state,
      MatchReduceFailureCode.wrongMatchMode,
      'This match has no asynchronous deadline.',
    );
  }
  if (event.deadlineToken != state.asyncDeadlineToken) {
    return _failure(
      state,
      MatchReduceFailureCode.staleTimer,
      'Async deadline token is stale.',
    );
  }
  if (event.elapsedSeconds <= 0) {
    return _failure(
      state,
      MatchReduceFailureCode.invalidElapsedSeconds,
      'Elapsed seconds must be positive.',
    );
  }
  final remaining = state.asyncDeadlineRemainingSeconds! - event.elapsedSeconds;
  if (remaining <= 0) {
    return MatchReduceResult(
      state: state.copyWith(
        phase: MatchPhase.finished,
        clearAsyncDeadline: true,
        finishedByDeadline: true,
      ),
    );
  }
  return MatchReduceResult(
    state: state.copyWith(
      asyncDeadlineRemainingSeconds: remaining,
      asyncDeadlineToken: state.asyncDeadlineToken + 1,
    ),
  );
}

MatchReduceResult _withdraw(
  MatchState state,
  WithdrawFromAsyncMatchEvent event,
) {
  if (state.config.matchMode != MatchMode.asynchronous) {
    return _failure(
      state,
      MatchReduceFailureCode.wrongMatchMode,
      'Only asynchronous matches support participant withdrawal.',
    );
  }
  final index = state.players.indexWhere(
    (player) => player.playerId == event.playerId,
  );
  if (index < 0) {
    return _failure(
      state,
      MatchReduceFailureCode.playerNotFound,
      'Player is not part of this match.',
    );
  }
  final players = state.players.toList();
  final player = players[index];
  players[index] = MatchPlayerState(
    playerId: player.playerId,
    session: player.session,
    replay: player.replay,
    withdrawn: true,
  );
  return MatchReduceResult(
    state: state.copyWith(
      phase: MatchPhase.finished,
      players: players,
      clearAsyncDeadline: true,
    ),
  );
}

MatchReduceResult _advanceRound(MatchState state) {
  final players = <MatchPlayerState>[];
  for (final player in state.players) {
    var session = player.session;
    var replay = player.replay;
    if (session.isCurrentRoundFinished) {
      final nextRound = recordAction(
        replay,
        session,
        const StartNextRoundAction(),
      );
      if (!nextRound.reduceResult.isSuccess) {
        return _failure(
          state,
          MatchReduceFailureCode.actionRejected,
          nextRound.reduceResult.sessionError?.message ??
              'Unable to start the next round.',
        );
      }
      session = nextRound.state;
      replay = nextRound.replay;
    }
    final timerStart = recordAction(
      replay,
      session,
      const PlayRoundAction(StartRoundTimerAction()),
    );
    if (!timerStart.reduceResult.isSuccess) {
      return _failure(
        state,
        MatchReduceFailureCode.actionRejected,
        timerStart.reduceResult.sessionError?.message ??
            timerStart.reduceResult.roundError?.message ??
            'Unable to start the next live round timer.',
      );
    }
    players.add(
      MatchPlayerState(
        playerId: player.playerId,
        session: timerStart.state,
        replay: timerStart.replay,
      ),
    );
  }
  return MatchReduceResult(
    state: state.copyWith(
      phase: MatchPhase.playing,
      currentRoundNumber: state.currentRoundNumber + 1,
      players: players,
      intermissionRemainingSeconds: 0,
      intermissionDeadlineToken: state.intermissionDeadlineToken + 1,
      skipVotes: const <String>{},
    ),
  );
}

MatchReduceResult _failure(
  MatchState state,
  MatchReduceFailureCode code,
  String message,
) {
  return MatchReduceResult(
    state: state,
    failure: MatchReduceFailure(code: code, message: message),
  );
}
