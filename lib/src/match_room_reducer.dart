part of '../tripeaks_engine.dart';

/// Applies one [event] to [state] using pure deterministic reducer.
MatchReduceResult tryReduceMatch(MatchState state, MatchEvent event) {
  switch (event) {
    case JoinMatchEvent(playerId: final playerId):
      if (state.players.any((player) => player.playerId == playerId)) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerAlreadyJoined,
            message: 'Player already joined.',
          ),
        );
      }
      if (state.players.length >= state.config.maxPlayers) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchFull,
            message: 'Match is full.',
          ),
        );
      }
      if (state.matchStatus != MatchStatus.waiting) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyStarted,
            message: 'Match already started.',
          ),
        );
      }
      final nextPlayers = <MatchPlayerState>[
        ...state.players,
        MatchPlayerState(playerId: playerId, status: PlayerStatus.joined),
      ];
      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case LeaveMatchEvent(playerId: final playerId):
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
      final nextPlayers = state.players.toList(growable: false);
      final player = nextPlayers[index];
      nextPlayers[index] = player._copyWith(status: PlayerStatus.left);
      final maybeFinished = _deriveMatchStatusAfterPlayerUpdate(
        state.matchStatus,
        nextPlayers,
      );
      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          matchStatus: maybeFinished,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case StartMatchEvent():
      if (state.matchStatus == MatchStatus.finished) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyFinished,
            message: 'Match already finished.',
          ),
        );
      }
      if (state.matchStatus != MatchStatus.waiting) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyStarted,
            message: 'Match already started.',
          ),
        );
      }
      if (state.players.isEmpty) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchNotStarted,
            message: 'Cannot start without players.',
          ),
        );
      }

      final nextPlayers = <MatchPlayerState>[];
      for (final player in state.players) {
        if (player.status == PlayerStatus.left) {
          nextPlayers.add(player);
          continue;
        }
        final deal = newGameWithDealPolicy(
          state.config.matchSeed,
          scoreConfig: state.config.scoreConfig,
          roundRulesConfig: state.config.roundRulesConfig,
          undoConfig: state.config.undoConfig,
          streakConfig: state.config.streakConfig,
          strikeTimerConfig: state.config.strikeTimerConfig,
          bonusSlotsConfig: state.config.bonusSlotsConfig,
          dealPolicy: state.config.dealPolicyConfig,
        );
        if (!deal.isSuccess) {
          return MatchReduceResult(
            state: state,
            failure: const MatchReduceFailure(
              code: MatchReduceFailureCode.matchNotStarted,
              message: 'Unable to create deterministic match deal.',
            ),
          );
        }

        final round = deal.state!;
        final session = TriPeaksSessionState.newSession(
          ruleset: state.config.ruleset,
          seed: deal.attemptSeed,
          scoreConfig: state.config.scoreConfig,
          roundRulesConfig: state.config.roundRulesConfig,
          undoConfig: state.config.undoConfig,
          streakConfig: state.config.streakConfig,
          strikeTimerConfig: state.config.strikeTimerConfig,
          bonusSlotsConfig: state.config.bonusSlotsConfig,
        );
        final replay = ReplaySession.newSession(
          seed: session.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: session.ruleset,
          scoreConfig: session.scoreConfig,
          roundRulesConfig: session.roundRulesConfig,
          undoConfig: session.undoConfig,
          streakConfig: session.streakConfig,
          strikeTimerConfig: session.strikeTimerConfig,
          bonusSlotsConfig: session.bonusSlotsConfig,
        );
        final initialized = session._copyWith(currentRound: round);
        nextPlayers.add(
          player._copyWith(
            status: PlayerStatus.active,
            session: initialized,
            replay: replay,
            latestFingerprint: sessionFingerprint(initialized),
            clearFinishOrderIndex: true,
          ),
        );
      }

      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          matchStatus: MatchStatus.active,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

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
      if (state.matchStatus != MatchStatus.active) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchNotStarted,
            message: 'Match is not active.',
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
  if (current == MatchStatus.waiting) {
    return current;
  }
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
