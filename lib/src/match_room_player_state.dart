part of '../tripeaks_engine.dart';

/// Per-player state inside a match.
final class MatchPlayerState {
  /// Creates player match state.
  const MatchPlayerState({
    required this.playerId,
    required this.status,
    this.session,
    this.replay,
    this.latestFingerprint,
    this.finishOrderIndex,
  });

  /// Stable player id.
  final String playerId;

  /// Player lifecycle status.
  final PlayerStatus status;

  /// Player independent session state.
  final TriPeaksSessionState? session;

  /// Player attempt replay log.
  final ReplaySession? replay;

  /// Latest deterministic state fingerprint.
  final String? latestFingerprint;

  /// Optional deterministic finish order index.
  final int? finishOrderIndex;

  MatchPlayerState _copyWith({
    PlayerStatus? status,
    TriPeaksSessionState? session,
    ReplaySession? replay,
    String? latestFingerprint,
    bool clearLatestFingerprint = false,
    int? finishOrderIndex,
    bool clearFinishOrderIndex = false,
  }) {
    return MatchPlayerState(
      playerId: playerId,
      status: status ?? this.status,
      session: session ?? this.session,
      replay: replay ?? this.replay,
      latestFingerprint: clearLatestFingerprint
          ? null
          : (latestFingerprint ?? this.latestFingerprint),
      finishOrderIndex: clearFinishOrderIndex
          ? null
          : (finishOrderIndex ?? this.finishOrderIndex),
    );
  }

  /// Serializes player state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_player_state',
      'playerId': playerId,
      'status': status.name,
      if (session case final value?) 'session': value.toMap(),
      if (replay case final value?) 'replay': value.toMap(),
      if (latestFingerprint case final value?) 'latestFingerprint': value,
      if (finishOrderIndex case final value?) 'finishOrderIndex': value,
    };
  }

  /// Decodes player state from map without throwing.
  static DecodeResult<MatchPlayerState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_player_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final playerId = map['playerId'];
    final statusName = map['status'];
    final latestFingerprint = map['latestFingerprint'];
    final finishOrderIndex = map['finishOrderIndex'];
    if (playerId is! String ||
        statusName is! String ||
        (latestFingerprint != null && latestFingerprint is! String) ||
        (finishOrderIndex != null && finishOrderIndex is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match player primitive fields.',
        ),
      );
    }

    TriPeaksSessionState? session;
    final sessionMap = map['session'];
    if (sessionMap != null) {
      if (sessionMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'session must be a map when present.',
          ),
        );
      }
      final sessionResult = TriPeaksSessionState.tryFromMap(sessionMap);
      if (!sessionResult.isSuccess) {
        return DecodeResult.failure(sessionResult.error!);
      }
      session = sessionResult.value!;
    }

    ReplaySession? replay;
    final replayMap = map['replay'];
    if (replayMap != null) {
      if (replayMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'replay must be a map when present.',
          ),
        );
      }
      final replayResult = ReplaySession.tryFromMap(replayMap);
      if (!replayResult.isSuccess) {
        return DecodeResult.failure(replayResult.error!);
      }
      replay = replayResult.value!;
    }

    try {
      return DecodeResult.success(
        MatchPlayerState(
          playerId: playerId,
          status: PlayerStatus.values.byName(statusName),
          session: session,
          replay: replay,
          latestFingerprint: latestFingerprint as String?,
          finishOrderIndex: finishOrderIndex as int?,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match player payload: $error',
        ),
      );
    }
  }
}
