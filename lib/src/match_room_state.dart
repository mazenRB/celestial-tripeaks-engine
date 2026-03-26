part of '../tripeaks_engine.dart';

/// Full multiplayer match state.
final class MatchState {
  /// Creates match state.
  const MatchState({
    required this.schemaVersion,
    required this.engineVersion,
    required this.config,
    required this.matchStatus,
    required this.authoritativeSequence,
    required this.players,
    this.finalResult,
  });

  /// Creates initial waiting match state.
  factory MatchState.newMatch({required MatchConfig config}) {
    return MatchState(
      schemaVersion: _serializationSchemaV1,
      engineVersion: config.engineVersion,
      config: config,
      matchStatus: MatchStatus.waiting,
      authoritativeSequence: 0,
      players: const <MatchPlayerState>[],
      finalResult: null,
    );
  }

  /// State schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Match config.
  final MatchConfig config;

  /// Match lifecycle status.
  final MatchStatus matchStatus;

  /// Authoritative total ordering sequence.
  final int authoritativeSequence;

  /// Player states in deterministic join order.
  final List<MatchPlayerState> players;

  /// Immutable final match result once finalized.
  final FinalMatchResult? finalResult;

  MatchState _copyWith({
    MatchStatus? matchStatus,
    int? authoritativeSequence,
    List<MatchPlayerState>? players,
    FinalMatchResult? finalResult,
    bool clearFinalResult = false,
  }) {
    return MatchState(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      config: config,
      matchStatus: matchStatus ?? this.matchStatus,
      authoritativeSequence:
          authoritativeSequence ?? this.authoritativeSequence,
      players: List<MatchPlayerState>.unmodifiable(players ?? this.players),
      finalResult: clearFinalResult ? null : (finalResult ?? this.finalResult),
    );
  }

  /// Serializes match state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'match_state',
      'engineVersion': engineVersion,
      'config': config.toMap(),
      'matchStatus': matchStatus.name,
      'authoritativeSequence': authoritativeSequence,
      'players':
          players.map((player) => player.toMap()).toList(growable: false),
      if (finalResult case final value?) 'finalResult': value.toMap(),
    };
  }

  /// Decodes match state from map without throwing.
  static DecodeResult<MatchState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final configMap = map['config'];
    if (configMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'config must be a map.',
        ),
      );
    }
    final configResult = MatchConfig.tryFromMap(configMap);
    if (!configResult.isSuccess) {
      return DecodeResult.failure(configResult.error!);
    }

    final statusName = map['matchStatus'];
    final engineVersion = map['engineVersion'];
    final seq = map['authoritativeSequence'];
    final playersRaw = map['players'];
    final finalResultRaw = map['finalResult'];
    if (statusName is! String ||
        engineVersion is! int ||
        seq is! int ||
        playersRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match state primitive fields.',
        ),
      );
    }

    final players = <MatchPlayerState>[];
    for (final raw in playersRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'players items must be maps.',
          ),
        );
      }
      final playerResult = MatchPlayerState.tryFromMap(raw);
      if (!playerResult.isSuccess) {
        return DecodeResult.failure(playerResult.error!);
      }
      players.add(playerResult.value!);
    }

    FinalMatchResult? finalResult;
    if (finalResultRaw != null) {
      if (finalResultRaw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'finalResult must be a map when present.',
          ),
        );
      }
      final finalResultDecode = FinalMatchResult.tryFromMap(finalResultRaw);
      if (!finalResultDecode.isSuccess) {
        return DecodeResult.failure(finalResultDecode.error!);
      }
      finalResult = finalResultDecode.value!;
    }

    try {
      return DecodeResult.success(
        MatchState(
          schemaVersion: _serializationSchemaV1,
          engineVersion: engineVersion,
          config: configResult.value!,
          matchStatus: MatchStatus.values.byName(statusName),
          authoritativeSequence: seq,
          players: List<MatchPlayerState>.unmodifiable(players),
          finalResult: finalResult,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match state payload: $error',
        ),
      );
    }
  }
}
