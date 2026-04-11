part of 'tripeaks_engine_internal.dart';

/// Deterministic finalization condition.
enum MatchFinishCondition {
  allPlayersFinished,
  firstFinisherEnds,
  timeoutEnds,
}

/// Config for deterministic match finalization.
final class MatchFinalizationConfig {
  /// Creates finalization config.
  const MatchFinalizationConfig({
    this.finishCondition = MatchFinishCondition.allPlayersFinished,
    this.allowAbortFinish = false,
    this.scoringConfig = const MatchScoringConfig(),
  });

  /// Finalization trigger condition.
  final MatchFinishCondition finishCondition;

  /// Whether finalization can proceed with unfinished/left players.
  final bool allowAbortFinish;

  /// Additive scoring policy used to produce final results.
  final MatchScoringConfig scoringConfig;
}

/// Final player outcome at match finalization.
enum MatchPlayerOutcome {
  finished,
  left,
  aborted,
  disqualified,
}

/// Final per-player score breakdown.
final class FinalPlayerBreakdown {
  /// Creates final player breakdown.
  const FinalPlayerBreakdown({
    required this.roundScore,
    required this.bonuses,
    required this.penalties,
  });

  /// Mechanics-derived score.
  final int roundScore;

  /// Additive bonus points.
  final int bonuses;

  /// Additive penalties (usually `<= 0`).
  final int penalties;

  /// Final match score.
  int get finalScore => roundScore + bonuses + penalties;

  /// Serializes breakdown to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'final_player_breakdown',
      'roundScore': roundScore,
      'bonuses': bonuses,
      'penalties': penalties,
      'finalScore': finalScore,
    };
  }

  /// Decodes breakdown from map without throwing.
  static DecodeResult<FinalPlayerBreakdown> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'final_player_breakdown') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final roundScore = map['roundScore'];
    final bonuses = map['bonuses'];
    final penalties = map['penalties'];
    if (roundScore is! int || bonuses is! int || penalties is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid FinalPlayerBreakdown payload.',
        ),
      );
    }
    return DecodeResult.success(
      FinalPlayerBreakdown(
        roundScore: roundScore,
        bonuses: bonuses,
        penalties: penalties,
      ),
    );
  }
}

/// Immutable finalized match result contract.
final class FinalMatchResult {
  /// Creates final match result.
  const FinalMatchResult({
    required this.schemaVersion,
    required this.engineVersion,
    required this.matchId,
    required this.matchSeed,
    required this.finishedAtAuthoritativeSequence,
    required this.placements,
    required this.perPlayerBreakdown,
    required this.perPlayerFinalFingerprint,
    required this.perPlayerOutcome,
  });

  /// DTO schema version.
  final int schemaVersion;

  /// Engine version.
  final int engineVersion;

  /// Match identifier.
  final String matchId;

  /// Match deterministic seed.
  final int matchSeed;

  /// Authoritative sequence at finalization.
  final int finishedAtAuthoritativeSequence;

  /// Ordered player ids by placement.
  final List<String> placements;

  /// Per-player breakdown.
  final Map<String, FinalPlayerBreakdown> perPlayerBreakdown;

  /// Per-player final fingerprint.
  final Map<String, String> perPlayerFinalFingerprint;

  /// Per-player final outcome.
  final Map<String, MatchPlayerOutcome> perPlayerOutcome;

  /// Serializes result to map.
  Map<String, dynamic> toMap() {
    final sortedPlayers = perPlayerBreakdown.keys.toList(growable: false)
      ..sort();
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'final_match_result',
      'engineVersion': engineVersion,
      'matchId': matchId,
      'matchSeed': matchSeed,
      'finishedAtAuthoritativeSequence': finishedAtAuthoritativeSequence,
      'placements': placements,
      'perPlayerBreakdown': <String, dynamic>{
        for (final player in sortedPlayers)
          player: perPlayerBreakdown[player]!.toMap(),
      },
      'perPlayerFinalFingerprint': <String, String>{
        for (final player
            in perPlayerFinalFingerprint.keys.toList(growable: false)..sort())
          player: perPlayerFinalFingerprint[player]!,
      },
      'perPlayerOutcome': <String, String>{
        for (final player
            in perPlayerOutcome.keys.toList(growable: false)..sort())
          player: perPlayerOutcome[player]!.name,
      },
    };
  }

  /// Decodes result from map without throwing.
  static DecodeResult<FinalMatchResult> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'final_match_result') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final engineVersion = map['engineVersion'];
    final matchId = map['matchId'];
    final matchSeed = map['matchSeed'];
    final finishedAt = map['finishedAtAuthoritativeSequence'];
    final placementsRaw = map['placements'];
    final breakdownRaw = map['perPlayerBreakdown'];
    final fingerprintRaw = map['perPlayerFinalFingerprint'];
    final outcomeRaw = map['perPlayerOutcome'];
    if (engineVersion is! int ||
        matchId is! String ||
        matchSeed is! int ||
        finishedAt is! int ||
        placementsRaw is! List<dynamic> ||
        breakdownRaw is! Map<String, dynamic> ||
        fingerprintRaw is! Map<String, dynamic> ||
        outcomeRaw is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid FinalMatchResult payload.',
        ),
      );
    }
    if (placementsRaw.any((value) => value is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'placements must contain strings.',
        ),
      );
    }
    final breakdown = <String, FinalPlayerBreakdown>{};
    for (final entry in breakdownRaw.entries) {
      if (entry.value is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'perPlayerBreakdown values must be maps.',
          ),
        );
      }
      final decoded =
          FinalPlayerBreakdown.tryFromMap(entry.value as Map<String, dynamic>);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      breakdown[entry.key] = decoded.value!;
    }
    final fingerprints = <String, String>{};
    for (final entry in fingerprintRaw.entries) {
      if (entry.value is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'perPlayerFinalFingerprint values must be strings.',
          ),
        );
      }
      fingerprints[entry.key] = entry.value as String;
    }
    final outcomes = <String, MatchPlayerOutcome>{};
    for (final entry in outcomeRaw.entries) {
      if (entry.value is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'perPlayerOutcome values must be strings.',
          ),
        );
      }
      try {
        outcomes[entry.key] = MatchPlayerOutcome.values.byName(
          entry.value as String,
        );
      } on Object catch (error) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Invalid perPlayerOutcome payload: $error',
          ),
        );
      }
    }
    return DecodeResult.success(
      FinalMatchResult(
        schemaVersion: _serializationSchemaV1,
        engineVersion: engineVersion,
        matchId: matchId,
        matchSeed: matchSeed,
        finishedAtAuthoritativeSequence: finishedAt,
        placements: List<String>.unmodifiable(
          placementsRaw.cast<String>(),
        ),
        perPlayerBreakdown: Map<String, FinalPlayerBreakdown>.unmodifiable(
          breakdown,
        ),
        perPlayerFinalFingerprint: Map<String, String>.unmodifiable(
          fingerprints,
        ),
        perPlayerOutcome: Map<String, MatchPlayerOutcome>.unmodifiable(
          outcomes,
        ),
      ),
    );
  }
}

/// Finalization failure codes.
enum FinalizeFailureCode {
  cannotFinalize,
}

/// Typed finalization failure.
final class FinalizeFailure {
  /// Creates finalization failure details.
  const FinalizeFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly code.
  final FinalizeFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Result for deterministic match finalization.
final class FinalizeResult {
  /// Creates finalization result.
  const FinalizeResult({
    required this.isSuccess,
    this.reason,
    this.result,
    this.finishedMatchState,
    this.alreadyFinalized = false,
  });

  /// Whether finalization succeeded.
  final bool isSuccess;

  /// Failure details for unsuccessful finalization.
  final FinalizeFailure? reason;

  /// Immutable final result when successful.
  final FinalMatchResult? result;

  /// Updated finished match state when successful.
  final MatchState? finishedMatchState;

  /// Whether this call returned previously stored result.
  final bool alreadyFinalized;
}
