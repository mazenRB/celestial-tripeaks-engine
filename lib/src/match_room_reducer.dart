part of 'tripeaks_engine_internal.dart';

/// Applies one [event] to [state] using pure deterministic reducer.
MatchReduceResult tryReduceMatch(MatchState state, MatchEvent event) {
  switch (event) {
    case SubmitMatchActionEvent(
        playerId: final playerId,
        action: final action,
        clientSeq: final clientSeq,
      ):
      if (state.matchStatus == MatchStatus.finished) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyFinished,
            message: 'Match is already finished.',
          ),
        );
      }
      final index = _playerIndex(state.players, playerId);
      if (index < 0) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerNotFound,
            message: 'Player not found.',
          ),
        );
      }
      final player = state.players[index];
      if (player.status != PlayerStatus.active || player.session == null) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerNotActive,
            message: 'Player is not active.',
          ),
        );
      }

      final nextSequence = state.authoritativeSequence + 1;
      final reduceResult = tryReduceTriPeaksSession(
        player.session!,
        action,
        tick: nextSequence,
      );

      final replay = recordAttempt(
        player.replay ??
            ReplaySession.newSession(
              seed: player.session!.seed ?? TriPeaksSessionState.defaultSeed,
              ruleset: player.session!.ruleset,
              scoreConfig: player.session!.scoreConfig,
              roundRulesConfig: player.session!.roundRulesConfig,
              roundTimerConfig: player.session!.roundTimerConfig,
              undoConfig: player.session!.undoConfig,
              streakConfig: player.session!.streakConfig,
              strikeTimerConfig: player.session!.strikeTimerConfig,
              bonusSlotsConfig: player.session!.bonusSlotsConfig,
            ),
        action,
        reduceResult,
        tick: clientSeq ?? nextSequence,
      );

      var nextPlayer = player._copyWith(
        session: reduceResult.state,
        replay: replay,
      );
      if (!identical(reduceResult.state, player.session) ||
          reduceResult.isSuccess) {
        nextPlayer = nextPlayer._copyWith(
          latestFingerprint: sessionFingerprint(reduceResult.state),
        );
      }

      if (nextPlayer.status == PlayerStatus.active &&
          reduceResult.state.isSessionFinished) {
        final finishOrder =
            state.players.where((p) => p.finishOrderIndex != null).length + 1;
        nextPlayer = nextPlayer._copyWith(
          status: PlayerStatus.finished,
          finishOrderIndex: finishOrder,
          latestFingerprint: sessionFingerprint(reduceResult.state),
        );
      }

      final nextPlayers = state.players.toList(growable: false);
      nextPlayers[index] = nextPlayer;

      final maybeFinished = _deriveMatchStatusAfterPlayerUpdate(
        state.matchStatus,
        nextPlayers,
      );

      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          authoritativeSequence: nextSequence,
          matchStatus: maybeFinished,
        ),
      );
  }
}

int _playerIndex(List<MatchPlayerState> players, String playerId) {
  for (var i = 0; i < players.length; i++) {
    if (players[i].playerId == playerId) {
      return i;
    }
  }
  return -1;
}

MatchStatus _deriveMatchStatusAfterPlayerUpdate(
  MatchStatus current,
  List<MatchPlayerState> players,
) {
  final unfinishedActive = players.any(
    (player) => player.status == PlayerStatus.active,
  );
  if (!unfinishedActive) {
    return MatchStatus.finished;
  }
  return MatchStatus.active;
}

/// Deterministically applies ordered [events] from [initial] state.
MatchState replayMatchEvents(MatchState initial, List<MatchEvent> events) {
  var state = initial;
  for (final event in events) {
    final result = tryReduceMatch(state, event);
    state = result.state;
  }
  return state;
}
