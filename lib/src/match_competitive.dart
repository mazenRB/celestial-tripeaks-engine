part of 'tripeaks_engine_internal.dart';

/// Deterministic tie-breaker policy for match placement ordering.
enum MatchTieBreakerPolicy {
  finishOrder,
  score,
  finishThenScore,
}

/// Optional timeout handling mode for async matches.
enum MatchTimeoutPolicy {
  none,
}

/// Config for additive competitive match scoring.
final class MatchScoringConfig {
  /// Creates competitive scoring config.
  const MatchScoringConfig({
    this.firstFinishBonus = 0,
    this.placementBonuses = const <int, int>{},
    this.tieBreakerPolicy = MatchTieBreakerPolicy.finishThenScore,
    this.timeoutPolicy = MatchTimeoutPolicy.none,
  });

  /// Bonus for the first finisher.
  final int firstFinishBonus;

  /// Placement bonus points by rank index (1-based).
  final Map<int, int> placementBonuses;

  /// Placement tie-breaker policy.
  final MatchTieBreakerPolicy tieBreakerPolicy;

  /// Optional timeout policy for async mode.
  final MatchTimeoutPolicy timeoutPolicy;
}

/// Score breakdown for one player in final match results.
final class MatchScoreBreakdown {
  /// Creates one player score breakdown.
  const MatchScoreBreakdown({
    required this.roundScore,
    required this.firstFinishBonus,
    required this.placementBonus,
  });

  /// Mechanics-derived score from player's independent session.
  final int roundScore;

  /// Bonus for first to finish.
  final int firstFinishBonus;

  /// Bonus based on final placement.
  final int placementBonus;

  /// Final additive total score.
  int get finalMatchScore => roundScore + firstFinishBonus + placementBonus;
}

/// One ordered placement entry in final match results.
final class MatchPlacement {
  /// Creates one match placement.
  const MatchPlacement({
    required this.placement,
    required this.playerId,
    required this.breakdown,
  });

  /// 1-based placement index.
  final int placement;

  /// Stable player identifier.
  final String playerId;

  /// Per-player score breakdown.
  final MatchScoreBreakdown breakdown;

  /// Final additive score.
  int get finalMatchScore => breakdown.finalMatchScore;
}

/// Deterministic final match result output.
final class MatchResult {
  /// Creates a match result.
  MatchResult({required List<MatchPlacement> placements})
      : placements = List<MatchPlacement>.unmodifiable(placements);

  /// Ordered placements from best to worst.
  final List<MatchPlacement> placements;

  /// Final score by player id.
  Map<String, int> get finalMatchScoreByPlayer {
    final out = <String, int>{};
    for (final placement in placements) {
      out[placement.playerId] = placement.finalMatchScore;
    }
    return Map<String, int>.unmodifiable(out);
  }
}

/// Computes deterministic final match results from [matchState].
MatchResult computeMatchResults(
  MatchState matchState,
  MatchScoringConfig scoringConfig,
) {
  final orderedPlayers = matchState.players.toList(growable: false)
    ..sort((a, b) => _comparePlayers(a, b, scoringConfig.tieBreakerPolicy));

  final placements = <MatchPlacement>[];
  for (var i = 0; i < orderedPlayers.length; i++) {
    final player = orderedPlayers[i];
    final placement = i + 1;
    final roundScore = _playerRoundScore(player);
    final firstFinishBonus =
        player.finishOrderIndex == 1 ? scoringConfig.firstFinishBonus : 0;
    final placementBonus = scoringConfig.placementBonuses[placement] ?? 0;
    placements.add(
      MatchPlacement(
        placement: placement,
        playerId: player.playerId,
        breakdown: MatchScoreBreakdown(
          roundScore: roundScore,
          firstFinishBonus: firstFinishBonus,
          placementBonus: placementBonus,
        ),
      ),
    );
  }

  return MatchResult(placements: placements);
}

int _playerRoundScore(MatchPlayerState player) {
  final session = player.session;
  if (session == null) {
    return 0;
  }
  // Match scoring remains additive over the existing round/session mechanics.
  return session.currentRound.scoreState.totalScore;
}

int _comparePlayers(
  MatchPlayerState left,
  MatchPlayerState right,
  MatchTieBreakerPolicy policy,
) {
  switch (policy) {
    case MatchTieBreakerPolicy.finishOrder:
      return _compareByFinishOrder(left, right);

    case MatchTieBreakerPolicy.score:
      final scoreCmp = _compareIntDesc(
        _playerRoundScore(left),
        _playerRoundScore(right),
      );
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      final finishCmp = _compareByFinishOrder(left, right);
      if (finishCmp != 0) {
        return finishCmp;
      }
      return left.playerId.compareTo(right.playerId);

    case MatchTieBreakerPolicy.finishThenScore:
      final finishCmp = _compareByFinishOrder(left, right);
      if (finishCmp != 0) {
        return finishCmp;
      }
      final scoreCmp = _compareIntDesc(
        _playerRoundScore(left),
        _playerRoundScore(right),
      );
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      return left.playerId.compareTo(right.playerId);
  }
}

int _compareByFinishOrder(MatchPlayerState left, MatchPlayerState right) {
  final a = left.finishOrderIndex;
  final b = right.finishOrderIndex;
  if (a != null && b != null) {
    final cmp = a.compareTo(b);
    if (cmp != 0) {
      return cmp;
    }
    return 0;
  }
  if (a != null) {
    return -1;
  }
  if (b != null) {
    return 1;
  }
  return 0;
}

int _compareIntDesc(int a, int b) => b.compareTo(a);
