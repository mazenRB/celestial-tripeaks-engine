part of 'tripeaks_engine_internal.dart';

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
      authoritativeState.lastAcceptedClientSequenceByPlayer)
    ..[clientEvent.playerId] = clientEvent.clientSeq;
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
      acceptedRecord,
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

/// Handles player reconnect as a pure read-only operation.
ReconnectResult handleReconnect(
  ServerAuthorityState authoritativeState,
  ReconnectRequest request,
) {
  if (request.matchId != authoritativeState.matchState.config.matchId) {
    return const ReconnectResult(
      isSuccess: false,
      failure: ReconnectFailure(
        code: ReconnectFailureCode.matchIdMismatch,
        message: 'Reconnect matchId does not match authoritative match.',
      ),
    );
  }

  final player = authoritativeState.matchState.players.where(
    (value) => value.playerId == request.playerId,
  );
  if (player.isEmpty) {
    return const ReconnectResult(
      isSuccess: false,
      failure: ReconnectFailure(
        code: ReconnectFailureCode.playerNotFound,
        message: 'Player is not part of this match.',
      ),
    );
  }

  final currentPlayer = player.first;
  final authoritativeFingerprint = currentPlayer.latestFingerprint;
  final mustFullyResync = request.lastKnownFingerprint != null &&
      authoritativeFingerprint != null &&
      request.lastKnownFingerprint != authoritativeFingerprint;

  return ReconnectResult(
    isSuccess: true,
    snapshot: authoritativeState.matchState,
    authoritativeSequence: authoritativeState.matchState.authoritativeSequence,
    authoritativeFingerprint: authoritativeFingerprint,
    mustFullyResync: mustFullyResync,
  );
}
