part of 'tripeaks_engine_internal.dart';

/// Canonical room-owned match bootstrap payload.
final class MatchBootstrap {
  /// Creates a canonical bootstrap payload.
  const MatchBootstrap({
    required this.schemaVersion,
    required this.engineVersion,
    required this.roomId,
    required this.matchId,
    required this.matchOrdinal,
    required this.matchConfig,
    required this.matchState,
  });

  /// Serialization schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Source room identifier.
  final String roomId;

  /// Bootstrapped match identifier.
  final String matchId;

  /// Monotonic 1-based match ordinal for this room.
  final int matchOrdinal;

  /// Canonical match configuration.
  final MatchConfig matchConfig;

  /// Canonical live match baseline state.
  final MatchState matchState;

  /// Serializes bootstrap payload to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'match_bootstrap',
      'engineVersion': engineVersion,
      'roomId': roomId,
      'matchId': matchId,
      'matchOrdinal': matchOrdinal,
      'matchConfig': matchConfig.toMap(),
      'matchState': matchState.toMap(),
    };
  }

  /// Decodes bootstrap payload from map without throwing.
  static DecodeResult<MatchBootstrap> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_bootstrap') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final engineVersion = map['engineVersion'];
    final roomId = map['roomId'];
    final matchId = map['matchId'];
    final matchOrdinal = map['matchOrdinal'];
    final matchConfigMap = map['matchConfig'];
    final matchStateMap = map['matchState'];
    if (engineVersion is! int ||
        roomId is! String ||
        matchId is! String ||
        matchOrdinal is! int ||
        matchConfigMap is! Map<String, dynamic> ||
        matchStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match bootstrap payload.',
        ),
      );
    }

    final matchConfig = MatchConfig.tryFromMap(matchConfigMap);
    if (!matchConfig.isSuccess) {
      return DecodeResult.failure(matchConfig.error!);
    }

    final matchState = MatchState.tryFromMap(matchStateMap);
    if (!matchState.isSuccess) {
      return DecodeResult.failure(matchState.error!);
    }

    return DecodeResult.success(
      MatchBootstrap(
        schemaVersion: _serializationSchemaV1,
        engineVersion: engineVersion,
        roomId: roomId,
        matchId: matchId,
        matchOrdinal: matchOrdinal,
        matchConfig: matchConfig.value!,
        matchState: matchState.value!,
      ),
    );
  }
}
