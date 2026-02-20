part of '../tripeaks_engine.dart';

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

/// Full server-authoritative state wrapper.
final class ServerAuthorityState {
  /// Creates server authority state.
  const ServerAuthorityState({
    required this.matchState,
    required this.eventLog,
    required this.lastAcceptedClientSequenceByPlayer,
    required this.processedClientEventIdsByPlayer,
    required this.processedEventIdWindowSize,
  });

  /// Creates initial server authority state for a match.
  factory ServerAuthorityState.newAuthority({
    required MatchState matchState,
    int processedEventIdWindowSize = 256,
  }) {
    return ServerAuthorityState(
      matchState: matchState,
      eventLog: const <ServerEventRecord>[],
      lastAcceptedClientSequenceByPlayer: const <String, int>{},
      processedClientEventIdsByPlayer: const <String, List<String>>{},
      processedEventIdWindowSize: processedEventIdWindowSize,
    );
  }

  /// Authoritative match state.
  final MatchState matchState;

  /// Append-only processed server event log.
  final List<ServerEventRecord> eventLog;

  /// Last accepted per-player client sequence.
  final Map<String, int> lastAcceptedClientSequenceByPlayer;

  /// Bounded processed client event ids per player.
  final Map<String, List<String>> processedClientEventIdsByPlayer;

  /// Max tracked ids retained per player.
  final int processedEventIdWindowSize;

  ServerAuthorityState _copyWith({
    MatchState? matchState,
    List<ServerEventRecord>? eventLog,
    Map<String, int>? lastAcceptedClientSequenceByPlayer,
    Map<String, List<String>>? processedClientEventIdsByPlayer,
  }) {
    return ServerAuthorityState(
      matchState: matchState ?? this.matchState,
      eventLog: List<ServerEventRecord>.unmodifiable(eventLog ?? this.eventLog),
      lastAcceptedClientSequenceByPlayer: Map<String, int>.unmodifiable(
        lastAcceptedClientSequenceByPlayer ??
            this.lastAcceptedClientSequenceByPlayer,
      ),
      processedClientEventIdsByPlayer: Map<String, List<String>>.unmodifiable(
        (processedClientEventIdsByPlayer ??
                this.processedClientEventIdsByPlayer)
            .map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      ),
      processedEventIdWindowSize: processedEventIdWindowSize,
    );
  }
}

/// Result of one server-authoritative client event application.
final class ServerResult {
  /// Creates server apply result.
  const ServerResult({
    required this.status,
    required this.state,
    this.reason,
    this.authoritativeSequence,
  });

  /// Outcome status.
  final ServerApplyStatus status;

  /// Updated authority state.
  final ServerAuthorityState state;

  /// Typed reject reason when rejected.
  final ServerRejectReason? reason;

  /// Assigned authoritative sequence when accepted.
  final int? authoritativeSequence;

  /// Whether event was applied.
  bool get accepted => status == ServerApplyStatus.accepted;

  /// Whether result is non-error (accepted or duplicate ignored).
  bool get isSuccess => status != ServerApplyStatus.rejected;

  /// Whether event was duplicate and ignored.
  bool get duplicateIgnored => status == ServerApplyStatus.duplicateIgnored;
}

/// Applies one [clientEvent] into the authoritative server state.
ServerResult applyClientEvent(
  ServerAuthorityState authoritativeState,
  ClientEvent clientEvent,
) {
  if (clientEvent.matchId != authoritativeState.matchState.config.matchId) {
    return _rejectAndTrack(
      authoritativeState,
      clientEvent,
      ServerRejectReason.invalidClientEvent,
    );
  }
  if (!_isClientEventForPlayer(clientEvent)) {
    return _rejectAndTrack(
      authoritativeState,
      clientEvent,
      ServerRejectReason.invalidClientEvent,
    );
  }

  final processedForPlayer = authoritativeState
          .processedClientEventIdsByPlayer[clientEvent.playerId] ??
      const <String>[];
  if (processedForPlayer.contains(clientEvent.clientEventId)) {
    final duplicateRecord = ServerEventRecord(
      clientEvent: clientEvent,
      outcome: ServerApplyStatus.duplicateIgnored,
    );
    final next = authoritativeState._copyWith(
      eventLog: <ServerEventRecord>[
        ...authoritativeState.eventLog,
        duplicateRecord,
      ],
    );
    return ServerResult(
      status: ServerApplyStatus.duplicateIgnored,
      state: next,
    );
  }

  final lastAccepted = authoritativeState
      .lastAcceptedClientSequenceByPlayer[clientEvent.playerId];
  if (lastAccepted != null && clientEvent.clientSeq <= lastAccepted) {
    return _rejectAndTrack(
      authoritativeState,
      clientEvent,
      ServerRejectReason.outOfOrderOrDuplicate,
    );
  }

  final reduce =
      tryReduceMatch(authoritativeState.matchState, clientEvent.event);
  if (!reduce.isSuccess) {
    return _rejectAndTrack(
      authoritativeState,
      clientEvent,
      ServerRejectReason.reducerRejected,
    );
  }

  final assignedSequence = reduce.state.authoritativeSequence;
  final nextSequences = Map<String, int>.from(
    authoritativeState.lastAcceptedClientSequenceByPlayer,
  )..[clientEvent.playerId] = clientEvent.clientSeq;
  final nextProcessedIds = _appendProcessedClientEventId(
    authoritativeState,
    clientEvent.playerId,
    clientEvent.clientEventId,
  );

  final acceptedRecord = ServerEventRecord(
    clientEvent: clientEvent,
    outcome: ServerApplyStatus.accepted,
    authoritativeSequence: assignedSequence,
  );

  final nextState = authoritativeState._copyWith(
    matchState: reduce.state,
    eventLog: <ServerEventRecord>[
      ...authoritativeState.eventLog,
      acceptedRecord
    ],
    lastAcceptedClientSequenceByPlayer: nextSequences,
    processedClientEventIdsByPlayer: nextProcessedIds,
  );

  return ServerResult(
    status: ServerApplyStatus.accepted,
    state: nextState,
    authoritativeSequence: assignedSequence,
  );
}

bool _isClientEventForPlayer(ClientEvent event) {
  switch (event.event) {
    case JoinMatchEvent(playerId: final id):
      return id == event.playerId;
    case LeaveMatchEvent(playerId: final id):
      return id == event.playerId;
    case SubmitMatchActionEvent(playerId: final id):
      return id == event.playerId;
    case StartMatchEvent():
      return true;
  }
}

ServerResult _rejectAndTrack(
  ServerAuthorityState current,
  ClientEvent clientEvent,
  ServerRejectReason reason,
) {
  final nextProcessedIds = _appendProcessedClientEventId(
    current,
    clientEvent.playerId,
    clientEvent.clientEventId,
  );
  final rejected = ServerEventRecord(
    clientEvent: clientEvent,
    outcome: ServerApplyStatus.rejected,
    rejectReason: reason,
  );
  final next = current._copyWith(
    eventLog: <ServerEventRecord>[...current.eventLog, rejected],
    processedClientEventIdsByPlayer: nextProcessedIds,
  );
  return ServerResult(
    status: ServerApplyStatus.rejected,
    state: next,
    reason: reason,
  );
}

Map<String, List<String>> _appendProcessedClientEventId(
  ServerAuthorityState state,
  String playerId,
  String clientEventId,
) {
  final next = <String, List<String>>{};
  for (final entry in state.processedClientEventIdsByPlayer.entries) {
    next[entry.key] = List<String>.from(entry.value);
  }

  final list = List<String>.from(next[playerId] ?? const <String>[]);
  if (!list.contains(clientEventId)) {
    list.add(clientEventId);
    if (list.length > state.processedEventIdWindowSize) {
      list.removeRange(0, list.length - state.processedEventIdWindowSize);
    }
  }
  next[playerId] = list;
  return next;
}

/// Replays accepted server records from [log] to reconstruct match state.
MatchState replayAcceptedServerEvents(
  MatchState initial,
  List<ServerEventRecord> log,
) {
  var state = initial;
  for (final record in log) {
    if (record.outcome != ServerApplyStatus.accepted) {
      continue;
    }
    state = tryReduceMatch(state, record.clientEvent.event).state;
  }
  return state;
}
