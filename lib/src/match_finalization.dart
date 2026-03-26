part of '../tripeaks_engine.dart';

/// Returns whether [matchState] can be finalized under [config].
bool canFinalize(
  MatchState matchState,
  MatchFinalizationConfig config,
) {
  if (matchState.finalResult != null) {
    return true;
  }

  final players = matchState.players;
  switch (config.finishCondition) {
    case MatchFinishCondition.allPlayersFinished:
      final allTerminal = players.every((player) {
        if (player.status == PlayerStatus.finished ||
            player.status == PlayerStatus.left) {
          return true;
        }
        return config.allowAbortFinish;
      });
      return allTerminal;

    case MatchFinishCondition.firstFinisherEnds:
      final hasFirst = players.any((player) => player.finishOrderIndex == 1);
      if (!hasFirst) {
        return false;
      }
      if (!config.allowAbortFinish) {
        return players.every((player) => player.status != PlayerStatus.joined);
      }
      return true;

    case MatchFinishCondition.timeoutEnds:
      return true;
  }
}

/// Deterministically finalizes [matchState] into immutable result contract.
FinalizeResult finalizeMatch(
  MatchState matchState,
  MatchFinalizationConfig config,
) {
  if (matchState.finalResult case final existing?) {
    return FinalizeResult(
      isSuccess: true,
      result: existing,
      finishedMatchState: matchState,
      alreadyFinalized: true,
    );
  }

  if (!canFinalize(matchState, config)) {
    return const FinalizeResult(
      isSuccess: false,
      reason: FinalizeFailure(
        code: FinalizeFailureCode.cannotFinalize,
        message: 'Match cannot be finalized under current condition.',
      ),
    );
  }

  final ranking = computeMatchResults(matchState, config.scoringConfig);
  final placements = ranking.placements.map((p) => p.playerId).toList(
        growable: false,
      );
  final breakdown = <String, FinalPlayerBreakdown>{};
  for (final placement in ranking.placements) {
    final bonus = placement.breakdown.firstFinishBonus +
        placement.breakdown.placementBonus;
    breakdown[placement.playerId] = FinalPlayerBreakdown(
      roundScore: placement.breakdown.roundScore,
      bonuses: bonus,
      penalties: 0,
    );
  }

  final fingerprints = <String, String>{};
  final outcomes = <String, MatchPlayerOutcome>{};
  for (final player in matchState.players) {
    final fp = player.latestFingerprint ??
        (player.session == null ? 'none' : sessionFingerprint(player.session!));
    fingerprints[player.playerId] = fp;
    outcomes[player.playerId] = _resolvePlayerOutcome(player);
  }

  final result = FinalMatchResult(
    schemaVersion: _serializationSchemaV1,
    engineVersion: matchState.engineVersion,
    matchId: matchState.config.matchId,
    matchSeed: matchState.config.matchSeed,
    finishedAtAuthoritativeSequence: matchState.authoritativeSequence,
    placements: placements,
    perPlayerBreakdown: Map<String, FinalPlayerBreakdown>.unmodifiable(
      breakdown,
    ),
    perPlayerFinalFingerprint: Map<String, String>.unmodifiable(fingerprints),
    perPlayerOutcome: Map<String, MatchPlayerOutcome>.unmodifiable(outcomes),
  );

  final finishedState = matchState._copyWith(
    matchStatus: MatchStatus.finished,
    finalResult: result,
  );

  return FinalizeResult(
    isSuccess: true,
    result: result,
    finishedMatchState: finishedState,
  );
}

MatchPlayerOutcome _resolvePlayerOutcome(MatchPlayerState player) {
  switch (player.status) {
    case PlayerStatus.left:
      return MatchPlayerOutcome.left;
    case PlayerStatus.finished:
      final session = player.session;
      if (session != null &&
          session.roundResults.any((r) => r.outcome == RoundOutcome.aborted)) {
        return MatchPlayerOutcome.aborted;
      }
      return MatchPlayerOutcome.finished;
    case PlayerStatus.joined:
    case PlayerStatus.active:
      return MatchPlayerOutcome.disqualified;
  }
}
