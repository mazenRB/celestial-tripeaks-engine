part of '../tripeaks_engine.dart';

/// Config for additive match-level scoring outside round mechanics.
final class MatchScoreConfig {
  /// Creates a match score config.
  const MatchScoreConfig({
    this.firstFinishBonus = 0,
    this.rankingAdjustments = const <int, int>{},
  });

  /// Bonus applied for the first finisher event.
  final int firstFinishBonus;

  /// Optional points by final rank (for example: `{1: 10, 2: 4, 3: 0}`).
  final Map<int, int> rankingAdjustments;
}

/// Error codes for invalid match-scoring events.
enum MatchScoreErrorCode {
  firstFinishAlreadyAwarded,
}

/// Typed match-scoring error details.
final class MatchScoreError {
  /// Creates a match score error.
  const MatchScoreError({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final MatchScoreErrorCode code;

  /// Human-friendly error message.
  final String message;
}

/// Result from a non-throwing match score reducer operation.
final class MatchScoreReduceResult {
  /// Creates a match score reducer result.
  const MatchScoreReduceResult({
    required this.state,
    this.error,
  });

  /// Resulting match score state.
  final MatchScoreState state;

  /// Error details for invalid events.
  final MatchScoreError? error;

  /// Whether reduction succeeded.
  bool get isSuccess => error == null;
}

/// Base type for ordered match-scoring events.
sealed class MatchScoreEvent {
  const MatchScoreEvent();
}

/// Event that commits one completed round score for a player.
final class RoundScoreAggregated extends MatchScoreEvent {
  /// Creates a round-score aggregation event.
  const RoundScoreAggregated({
    required this.playerId,
    required this.roundScore,
  });

  /// Stable player identifier.
  final String playerId;

  /// Round score to add for the player.
  final int roundScore;
}

/// Explicit event applying first-finisher bonus.
final class FirstFinishBonusApplied extends MatchScoreEvent {
  /// Creates a first-finish bonus event.
  const FirstFinishBonusApplied({required this.playerId});

  /// Stable player identifier.
  final String playerId;
}

/// Explicit event applying rank-based adjustment.
final class RankingAdjustmentApplied extends MatchScoreEvent {
  /// Creates a ranking adjustment event.
  const RankingAdjustmentApplied({
    required this.playerId,
    required this.rank,
  });

  /// Stable player identifier.
  final String playerId;

  /// Final rank.
  final int rank;
}

/// Immutable match/session-level score state.
final class MatchScoreState {
  /// Creates an empty match score state.
  const MatchScoreState({
    this.config = const MatchScoreConfig(),
    this.roundScoresByPlayer = const <String, int>{},
    this.multiplayerBonusesByPlayer = const <String, int>{},
    this.competitiveAdjustmentsByPlayer = const <String, int>{},
    this.firstFinishAwardedTo,
    this.processedEventsCount = 0,
  });

  /// Match-scoring config.
  final MatchScoreConfig config;

  /// Mechanics-derived round scores by player.
  final Map<String, int> roundScoresByPlayer;

  /// Multiplayer bonuses by player.
  final Map<String, int> multiplayerBonusesByPlayer;

  /// Competitive/ranking adjustments by player.
  final Map<String, int> competitiveAdjustmentsByPlayer;

  /// Player that received first-finish bonus.
  final String? firstFinishAwardedTo;

  /// Number of processed match-scoring events.
  final int processedEventsCount;

  /// Returns total score for [playerId].
  int totalFor(String playerId) {
    return (roundScoresByPlayer[playerId] ?? 0) +
        (multiplayerBonusesByPlayer[playerId] ?? 0) +
        (competitiveAdjustmentsByPlayer[playerId] ?? 0);
  }

  /// Returns combined totals by player.
  Map<String, int> get totalScoresByPlayer {
    final players = <String>{
      ...roundScoresByPlayer.keys,
      ...multiplayerBonusesByPlayer.keys,
      ...competitiveAdjustmentsByPlayer.keys,
    };
    final totals = <String, int>{};
    for (final player in players) {
      totals[player] = totalFor(player);
    }
    return Map<String, int>.unmodifiable(totals);
  }

  MatchScoreState _copyWith({
    Map<String, int>? roundScoresByPlayer,
    Map<String, int>? multiplayerBonusesByPlayer,
    Map<String, int>? competitiveAdjustmentsByPlayer,
    String? firstFinishAwardedTo,
    bool clearFirstFinishAwardedTo = false,
    int? processedEventsCount,
  }) {
    return MatchScoreState(
      config: config,
      roundScoresByPlayer: Map<String, int>.unmodifiable(
        roundScoresByPlayer ?? this.roundScoresByPlayer,
      ),
      multiplayerBonusesByPlayer: Map<String, int>.unmodifiable(
        multiplayerBonusesByPlayer ?? this.multiplayerBonusesByPlayer,
      ),
      competitiveAdjustmentsByPlayer: Map<String, int>.unmodifiable(
        competitiveAdjustmentsByPlayer ?? this.competitiveAdjustmentsByPlayer,
      ),
      firstFinishAwardedTo: clearFirstFinishAwardedTo
          ? null
          : (firstFinishAwardedTo ?? this.firstFinishAwardedTo),
      processedEventsCount: processedEventsCount ?? this.processedEventsCount,
    );
  }
}

/// Error codes for invalid TriPeaks actions.
