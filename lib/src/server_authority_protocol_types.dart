part of 'tripeaks_engine_internal.dart';

/// Typed server rejection reasons for client-submitted events.
enum ServerRejectReason {
  invalidClientEvent,
  outOfOrderOrDuplicate,
  reducerRejected,
}

/// Authoritative server apply status.
enum ServerApplyStatus {
  accepted,
  duplicateIgnored,
  rejected,
}

/// Versioned client event intent envelope.
final class ClientEvent {
  /// Creates a client event envelope.
  const ClientEvent({
    required this.matchId,
    required this.playerId,
    required this.clientEventId,
    required this.clientSeq,
    required this.event,
    this.schemaVersion = _serializationSchemaV1,
  });

  /// Envelope schema version.
  final int schemaVersion;

  /// Target match id.
  final String matchId;

  /// Submitting player id.
  final String playerId;

  /// Stable unique per-player event id.
  final String clientEventId;

  /// Monotonic client sequence per player.
  final int clientSeq;

  /// Intended match event payload.
  final MatchEvent event;

  /// Serializes client event to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'client_event',
      'matchId': matchId,
      'playerId': playerId,
      'clientEventId': clientEventId,
      'clientSeq': clientSeq,
      'event': event.toMap(),
    };
  }

  /// Decodes client event from map without throwing.
  static DecodeResult<ClientEvent> tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'schemaVersion must be an int.',
        ),
      );
    }
    if (schemaVersion != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion $schemaVersion.',
        ),
      );
    }
    if (map['type'] != 'client_event') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final matchId = map['matchId'];
    final playerId = map['playerId'];
    final clientEventId = map['clientEventId'];
    final clientSeq = map['clientSeq'];
    final eventMap = map['event'];
    if (matchId is! String ||
        playerId is! String ||
        clientEventId is! String ||
        clientSeq is! int ||
        eventMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid client_event envelope fields.',
        ),
      );
    }

    final decodedEvent = tryDecodeMatchEvent(eventMap);
    if (!decodedEvent.isSuccess) {
      return DecodeResult.failure(decodedEvent.error!);
    }

    return DecodeResult.success(
      ClientEvent(
        schemaVersion: schemaVersion,
        matchId: matchId,
        playerId: playerId,
        clientEventId: clientEventId,
        clientSeq: clientSeq,
        event: decodedEvent.value!,
      ),
    );
  }
}

/// One authoritative processed server-log entry.
final class ServerEventRecord {
  /// Creates a server event record.
  const ServerEventRecord({
    required this.clientEvent,
    required this.outcome,
    this.authoritativeSequence,
    this.rejectReason,
  });

  /// Original client intent.
  final ClientEvent clientEvent;

  /// Processing outcome.
  final ServerApplyStatus outcome;

  /// Assigned authoritative sequence when accepted.
  final int? authoritativeSequence;

  /// Reject reason when rejected.
  final ServerRejectReason? rejectReason;

  /// Whether the event changed authoritative state.
  bool get accepted => outcome == ServerApplyStatus.accepted;

  /// Serializes record to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'server_event_record',
      'clientEvent': clientEvent.toMap(),
      'outcome': outcome.name,
      if (authoritativeSequence case final value?)
        'authoritativeSequence': value,
      if (rejectReason case final value?) 'rejectReason': value.name,
    };
  }

  /// Decodes record from map without throwing.
  static DecodeResult<ServerEventRecord> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'server_event_record') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final clientEventMap = map['clientEvent'];
    final outcomeName = map['outcome'];
    final authSeq = map['authoritativeSequence'];
    final rejectReasonName = map['rejectReason'];
    if (clientEventMap is! Map<String, dynamic> ||
        outcomeName is! String ||
        (authSeq != null && authSeq is! int) ||
        (rejectReasonName != null && rejectReasonName is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid server_event_record payload.',
        ),
      );
    }

    final clientEvent = ClientEvent.tryFromMap(clientEventMap);
    if (!clientEvent.isSuccess) {
      return DecodeResult.failure(clientEvent.error!);
    }

    try {
      return DecodeResult.success(
        ServerEventRecord(
          clientEvent: clientEvent.value!,
          outcome: ServerApplyStatus.values.byName(outcomeName),
          authoritativeSequence: authSeq as int?,
          rejectReason: rejectReasonName == null
              ? null
              : ServerRejectReason.values.byName(rejectReasonName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid server_event_record payload: $error',
        ),
      );
    }
  }
}
