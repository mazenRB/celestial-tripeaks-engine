part of 'tripeaks_engine_internal.dart';

/// Accepted authoritative event persisted to durable storage.
final class PersistedAuthorityEvent {
  /// Creates a persisted accepted event.
  const PersistedAuthorityEvent({
    required this.schemaVersion,
    required this.engineVersion,
    required this.matchId,
    required this.authoritativeSequence,
    required this.playerId,
    required this.clientSeq,
    required this.clientEventId,
    required this.clientEvent,
    required this.serverRecord,
  });

  /// Builds a persisted accepted event from [record].
  factory PersistedAuthorityEvent.fromAcceptedRecord({
    required int engineVersion,
    required String matchId,
    required ServerEventRecord record,
  }) {
    return PersistedAuthorityEvent(
      schemaVersion: _serializationSchemaV1,
      engineVersion: engineVersion,
      matchId: matchId,
      authoritativeSequence: record.authoritativeSequence!,
      playerId: record.clientEvent.playerId,
      clientSeq: record.clientEvent.clientSeq,
      clientEventId: record.clientEvent.clientEventId,
      clientEvent: record.clientEvent,
      serverRecord: record,
    );
  }

  /// Parses from [map] without throwing.
  static DecodeResult<PersistedAuthorityEvent> tryFromMap(
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
    if (map['type'] != 'persisted_authority_event') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final engineVersion = map['engineVersion'];
    final matchId = map['matchId'];
    final authoritativeSequence = map['authoritativeSequence'];
    final playerId = map['playerId'];
    final clientSeq = map['clientSeq'];
    final clientEventId = map['clientEventId'];
    final clientEventMap = map['clientEvent'];
    final serverRecordMap = map['serverRecord'];
    if (engineVersion is! int ||
        matchId is! String ||
        authoritativeSequence is! int ||
        playerId is! String ||
        clientSeq is! int ||
        clientEventId is! String ||
        clientEventMap is! Map<String, dynamic> ||
        serverRecordMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid persisted authority event fields.',
        ),
      );
    }

    final decodedEvent = ClientEvent.tryFromMap(clientEventMap);
    if (!decodedEvent.isSuccess) {
      return DecodeResult.failure(decodedEvent.error!);
    }
    final decodedRecord = ServerEventRecord.tryFromMap(serverRecordMap);
    if (!decodedRecord.isSuccess) {
      return DecodeResult.failure(decodedRecord.error!);
    }
    final record = decodedRecord.value!;
    if (!record.accepted ||
        record.authoritativeSequence != authoritativeSequence) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Persisted authority event must contain accepted record.',
        ),
      );
    }
    if (_fingerprintFromMap(record.clientEvent.toMap()) !=
        _fingerprintFromMap(decodedEvent.value!.toMap())) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Persisted event client payload mismatch.',
        ),
      );
    }

    return DecodeResult.success(
      PersistedAuthorityEvent(
        schemaVersion: _serializationSchemaV1,
        engineVersion: engineVersion,
        matchId: matchId,
        authoritativeSequence: authoritativeSequence,
        playerId: playerId,
        clientSeq: clientSeq,
        clientEventId: clientEventId,
        clientEvent: decodedEvent.value!,
        serverRecord: record,
      ),
    );
  }

  /// Serialization schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Owning match id.
  final String matchId;

  /// Accepted authoritative sequence.
  final int authoritativeSequence;

  /// Resolved player id.
  final String playerId;

  /// Monotonic client sequence.
  final int clientSeq;

  /// Stable per-player client event id.
  final String clientEventId;

  /// Canonical accepted client event.
  final ClientEvent clientEvent;

  /// Accepted server record used for state transition.
  final ServerEventRecord serverRecord;

  /// Serializes to a JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'persisted_authority_event',
      'engineVersion': engineVersion,
      'matchId': matchId,
      'authoritativeSequence': authoritativeSequence,
      'playerId': playerId,
      'clientSeq': clientSeq,
      'clientEventId': clientEventId,
      'clientEvent': clientEvent.toMap(),
      'serverRecord': serverRecord.toMap(),
    };
  }
}

/// Durable snapshot of authoritative runtime state.
final class PersistedAuthoritySnapshot {
  /// Creates a persisted snapshot.
  const PersistedAuthoritySnapshot({
    required this.schemaVersion,
    required this.engineVersion,
    required this.matchId,
    required this.authoritativeSequence,
    required this.matchState,
    required this.matchFingerprint,
    required this.recentClientEventIdsByPlayer,
    required this.lastAcceptedClientSeqByPlayer,
  });

  /// Creates a snapshot from runtime state.
  factory PersistedAuthoritySnapshot.fromRuntimeState(
    AuthorityRuntimeState runtimeState,
  ) {
    return PersistedAuthoritySnapshot(
      schemaVersion: _serializationSchemaV1,
      engineVersion: runtimeState.matchState.engineVersion,
      matchId: runtimeState.matchState.config.matchId,
      authoritativeSequence: runtimeState.matchState.authoritativeSequence,
      matchState: runtimeState.matchState,
      matchFingerprint: _fingerprintFromMap(runtimeState.matchState.toMap()),
      recentClientEventIdsByPlayer: runtimeState.recentClientEventIdsByPlayer,
      lastAcceptedClientSeqByPlayer: runtimeState.lastAcceptedClientSeqByPlayer,
    );
  }

  /// Parses from [map] without throwing.
  static DecodeResult<PersistedAuthoritySnapshot> tryFromMap(
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
    if (map['type'] != 'persisted_authority_snapshot') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final engineVersion = map['engineVersion'];
    final matchId = map['matchId'];
    final authoritativeSequence = map['authoritativeSequence'];
    final matchStateMap = map['matchState'];
    final matchFingerprint = map['matchFingerprint'];
    final recentRaw = map['recentClientEventIdsByPlayer'];
    final lastSeqRaw = map['lastAcceptedClientSeqByPlayer'];
    if (engineVersion is! int ||
        matchId is! String ||
        authoritativeSequence is! int ||
        matchStateMap is! Map<String, dynamic> ||
        matchFingerprint is! String ||
        recentRaw is! Map<String, dynamic> ||
        lastSeqRaw is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid persisted snapshot primitive fields.',
        ),
      );
    }

    final decodedState = MatchState.tryFromMap(matchStateMap);
    if (!decodedState.isSuccess) {
      return DecodeResult.failure(decodedState.error!);
    }

    final recomputedFingerprint = _fingerprintFromMap(
      decodedState.value!.toMap(),
    );
    if (recomputedFingerprint != matchFingerprint) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Persisted snapshot fingerprint mismatch.',
        ),
      );
    }

    final recent = <String, List<String>>{};
    for (final entry in recentRaw.entries) {
      final value = entry.value;
      if (value is! List<dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'recentClientEventIdsByPlayer values must be lists.',
          ),
        );
      }
      recent[entry.key] = value.map((item) => item.toString()).toList();
    }

    final lastSeq = <String, int>{};
    for (final entry in lastSeqRaw.entries) {
      final value = entry.value;
      if (value is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'lastAcceptedClientSeqByPlayer values must be ints.',
          ),
        );
      }
      lastSeq[entry.key] = value;
    }

    return DecodeResult.success(
      PersistedAuthoritySnapshot(
        schemaVersion: _serializationSchemaV1,
        engineVersion: engineVersion,
        matchId: matchId,
        authoritativeSequence: authoritativeSequence,
        matchState: decodedState.value!,
        matchFingerprint: matchFingerprint,
        recentClientEventIdsByPlayer: recent,
        lastAcceptedClientSeqByPlayer: lastSeq,
      ),
    );
  }

  /// Serialization schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Owning match id.
  final String matchId;

  /// Last applied accepted authoritative sequence.
  final int authoritativeSequence;

  /// Full authoritative match snapshot.
  final MatchState matchState;

  /// Fingerprint for corruption detection.
  final String matchFingerprint;

  /// Bounded per-player recent accepted event ids.
  final Map<String, List<String>> recentClientEventIdsByPlayer;

  /// Last accepted client sequence per player.
  final Map<String, int> lastAcceptedClientSeqByPlayer;

  /// Serializes to a JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'persisted_authority_snapshot',
      'engineVersion': engineVersion,
      'matchId': matchId,
      'authoritativeSequence': authoritativeSequence,
      'matchState': matchState.toMap(),
      'matchFingerprint': matchFingerprint,
      'recentClientEventIdsByPlayer': recentClientEventIdsByPlayer.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      'lastAcceptedClientSeqByPlayer': Map<String, int>.from(
        lastAcceptedClientSeqByPlayer,
      ),
    };
  }
}
