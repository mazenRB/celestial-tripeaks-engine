import 'package:celestial_tripeaks/tripeaks_engine.dart';

import 'multiplayer_config.dart';
import 'multiplayer_state.dart';

/// Adds finalized result access to multiplayer match state.
extension MatchStateResultData on MatchState {
  /// Final score data, or `null` until the match ends.
  MatchResult? get result =>
      phase == MatchPhase.finished ? MatchResult.fromState(this) : null;
}

/// Score and completion data for one independent participant run.
final class PlayerMatchResult {
  /// Creates a participant result.
  const PlayerMatchResult({
    required this.playerId,
    required this.totalScore,
    required this.roundScores,
    required this.finalFingerprint,
    required this.isComplete,
    required this.withdrew,
  });

  /// Participant identifier.
  final String playerId;

  /// Sum of scores from completed rounds.
  final int totalScore;

  /// Scores of completed rounds in their played order.
  final List<int> roundScores;

  /// Fingerprint of this participant's final session snapshot.
  final String finalFingerprint;

  /// Whether this participant completed the full ruleset.
  final bool isComplete;

  /// Whether this participant withdrew from Async.
  final bool withdrew;

  /// Serializes the player result.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_player_result',
        'playerId': playerId,
        'totalScore': totalScore,
        'roundScores': roundScores,
        'finalFingerprint': finalFingerprint,
        'isComplete': isComplete,
        'withdrew': withdrew,
      };

  /// Decodes a player result.
  static DecodeResult<PlayerMatchResult> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<PlayerMatchResult>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported player result schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_player_result') {
      return const DecodeResult<PlayerMatchResult>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown player result type.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        PlayerMatchResult(
          playerId: map['playerId'] as String,
          totalScore: map['totalScore'] as int,
          roundScores: List<int>.unmodifiable(
            (map['roundScores'] as List<dynamic>).cast<int>(),
          ),
          finalFingerprint: map['finalFingerprint'] as String,
          isComplete: map['isComplete'] as bool,
          withdrew: map['withdrew'] as bool,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid player result: $error',
        ),
      );
    }
  }
}

/// Final score data for full-match and per-round comparison.
final class MatchResult {
  /// Creates a final match result.
  const MatchResult({
    required this.schemaVersion,
    required this.matchId,
    required this.matchMode,
    required this.matchSeed,
    required this.finishedByDeadline,
    required this.players,
  });

  /// Serialization version for this result.
  final int schemaVersion;

  /// Match identifier.
  final String matchId;

  /// Mode used for the match.
  final MatchMode matchMode;

  /// Shared seed used by the participants.
  final int matchSeed;

  /// Whether Async ended because its configured deadline elapsed.
  final bool finishedByDeadline;

  /// Independent player results in fixed roster order.
  final List<PlayerMatchResult> players;

  /// Returns each player's total score for full-match comparison.
  Map<String, int> get totalScores => Map<String, int>.unmodifiable(
        <String, int>{
          for (final player in players) player.playerId: player.totalScore
        },
      );

  /// Returns scores for a one-based round, omitting players without that round.
  Map<String, int> scoresForRound(int roundNumber) {
    if (roundNumber < 1) throw RangeError.value(roundNumber, 'roundNumber');
    final scores = <String, int>{};
    for (final player in players) {
      if (player.roundScores.length >= roundNumber) {
        scores[player.playerId] = player.roundScores[roundNumber - 1];
      }
    }
    return Map<String, int>.unmodifiable(scores);
  }

  /// Serializes the match result.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'type': 'multiplayer_match_result',
        'matchId': matchId,
        'matchMode': matchMode.name,
        'matchSeed': matchSeed,
        'finishedByDeadline': finishedByDeadline,
        'players': players.map((player) => player.toMap()).toList(),
      };

  /// Creates result data from a finished match.
  factory MatchResult.fromState(MatchState state) {
    if (state.phase != MatchPhase.finished) {
      throw ArgumentError('Match results require a finished match.');
    }
    return MatchResult(
      schemaVersion: 1,
      matchId: state.config.matchId,
      matchMode: state.config.matchMode,
      matchSeed: state.config.matchSeed,
      finishedByDeadline: state.finishedByDeadline,
      players: List<PlayerMatchResult>.unmodifiable(
        state.players.map(
          (player) => PlayerMatchResult(
            playerId: player.playerId,
            totalScore: player.session.cumulativeFinishedRoundsScoreTotal,
            roundScores: List<int>.unmodifiable(
              player.session.roundResults.map(
                (round) => round.finalScore ?? 0,
              ),
            ),
            finalFingerprint: sessionFingerprint(player.session),
            isComplete: player.session.isSessionFinished,
            withdrew: player.withdrawn,
          ),
        ),
      ),
    );
  }

  /// Decodes a serialized match result.
  static DecodeResult<MatchResult> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<MatchResult>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported match result schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_match_result') {
      return const DecodeResult<MatchResult>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown match result type.',
        ),
      );
    }
    try {
      final players = <PlayerMatchResult>[];
      for (final raw in map['players'] as List<dynamic>) {
        final decoded = PlayerMatchResult.tryFromMap(
          raw as Map<String, dynamic>,
        );
        if (!decoded.isSuccess) return DecodeResult.failure(decoded.error!);
        players.add(decoded.value!);
      }
      return DecodeResult.success(
        MatchResult(
          schemaVersion: 1,
          matchId: map['matchId'] as String,
          matchMode: MatchMode.values.byName(map['matchMode'] as String),
          matchSeed: map['matchSeed'] as int,
          finishedByDeadline: map['finishedByDeadline'] as bool,
          players: List<PlayerMatchResult>.unmodifiable(players),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match result: $error',
        ),
      );
    }
  }
}
