part of '../tripeaks_engine.dart';

/// Host-provided context for one authority apply attempt.
final class AuthorityRequestContext {
  /// Creates request context.
  const AuthorityRequestContext({
    required this.subjectId,
    required this.playerId,
  });

  /// Authenticated identity from host auth boundary.
  final String subjectId;

  /// Server-resolved player id authorized for this match.
  final String playerId;
}

/// In-memory runtime state owned by [AuthorityRuntime].
final class AuthorityRuntimeState {
  /// Creates runtime state.
  const AuthorityRuntimeState({
    required this.matchState,
    required this.recentClientEventIdsByPlayer,
    required this.lastAcceptedClientSeqByPlayer,
    required this.idCapacityPerPlayer,
  });

  /// Creates baseline runtime state with authoritative sequence at 0.
  factory AuthorityRuntimeState.newBaseline({
    required MatchState matchState,
    required int idCapacityPerPlayer,
  }) {
    return AuthorityRuntimeState(
      matchState: matchState,
      recentClientEventIdsByPlayer: const <String, List<String>>{},
      lastAcceptedClientSeqByPlayer: const <String, int>{},
      idCapacityPerPlayer: idCapacityPerPlayer,
    );
  }

  /// Authoritative match state.
  final MatchState matchState;

  /// Recent accepted client event IDs by player.
  final Map<String, List<String>> recentClientEventIdsByPlayer;

  /// Last accepted client sequence by player.
  final Map<String, int> lastAcceptedClientSeqByPlayer;

  /// Per-player ring capacity.
  final int idCapacityPerPlayer;

  AuthorityRuntimeState _copyWith({
    MatchState? matchState,
    Map<String, List<String>>? recentClientEventIdsByPlayer,
    Map<String, int>? lastAcceptedClientSeqByPlayer,
  }) {
    return AuthorityRuntimeState(
      matchState: matchState ?? this.matchState,
      recentClientEventIdsByPlayer: Map<String, List<String>>.unmodifiable(
        (recentClientEventIdsByPlayer ?? this.recentClientEventIdsByPlayer).map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      ),
      lastAcceptedClientSeqByPlayer: Map<String, int>.unmodifiable(
        lastAcceptedClientSeqByPlayer ?? this.lastAcceptedClientSeqByPlayer,
      ),
      idCapacityPerPlayer: idCapacityPerPlayer,
    );
  }
}

/// Runtime apply result with duplicate and resync hints.
final class AuthorityApplyResult {
  /// Creates authority runtime apply result.
  const AuthorityApplyResult({
    required this.status,
    required this.state,
    required this.authoritativeSequence,
    this.failure,
    this.rejectReason,
    this.lastAcceptedClientSeq,
    this.mustFullyResync = false,
  });

  /// Outcome status.
  final ServerApplyStatus status;

  /// Updated runtime state.
  final AuthorityRuntimeState state;

  /// Current authoritative sequence after the attempt.
  final int authoritativeSequence;

  /// Typed failure details for rejected outcomes.
  final AuthorityApplyFailure? failure;

  /// Reject reason mapped from server rules when available.
  final ServerRejectReason? rejectReason;

  /// Last accepted client sequence for this player, when known.
  final int? lastAcceptedClientSeq;

  /// Whether client should perform full resync.
  final bool mustFullyResync;

  /// Whether the event was accepted.
  bool get accepted => status == ServerApplyStatus.accepted;

  /// Whether the event was duplicate and ignored.
  bool get duplicateIgnored => status == ServerApplyStatus.duplicateIgnored;

  /// Whether the result is rejected.
  bool get rejected => status == ServerApplyStatus.rejected;
}

/// Runtime restore result.
final class AuthorityRestoreResult {
  /// Creates restore result.
  const AuthorityRestoreResult({
    required this.isSuccess,
    required this.state,
    required this.snapshotSeq,
    this.failure,
    this.usedSnapshotFallback = false,
  });

  /// Whether restore was successful.
  final bool isSuccess;

  /// Restored runtime state.
  final AuthorityRuntimeState state;

  /// Snapshot sequence used as replay starting boundary.
  final int snapshotSeq;

  /// Failure details when restore fails.
  final AuthorityRestoreFailure? failure;

  /// Whether invalid snapshot fallback was used.
  final bool usedSnapshotFallback;
}

/// Orchestrates durability and restore around pure deterministic reducers.
final class AuthorityRuntime {
  /// Creates a runtime for one authoritative match stream.
  AuthorityRuntime({
    required this.store,
    required MatchState initialMatchState,
    this.config = const AuthorityRuntimeConfig(),
  })  : _initialMatchState = initialMatchState,
        _state = AuthorityRuntimeState.newBaseline(
          matchState: initialMatchState,
          idCapacityPerPlayer: config.processedClientEventIdsCapacityPerPlayer,
        ) {
    if (initialMatchState.authoritativeSequence != 0) {
      throw StateError(
        'Initial match state authoritativeSequence must start at 0.',
      );
    }
  }

  /// Durable store port.
  final AuthorityStorePort store;

  /// Runtime tuning configuration.
  final AuthorityRuntimeConfig config;

  final MatchState _initialMatchState;
  AuthorityRuntimeState _state;

  /// Current in-memory runtime state.
  AuthorityRuntimeState get state => _state;

  /// Restores runtime state from latest snapshot and accepted event tail.
  Future<AuthorityRestoreResult> restore(String matchId) async {
    if (matchId != _initialMatchState.config.matchId) {
      return AuthorityRestoreResult(
        isSuccess: false,
        state: _state,
        snapshotSeq: 0,
        failure: const AuthorityRestoreFailure(
          code: AuthorityRestoreFailureCode.matchIdMismatch,
          message: 'Requested matchId does not match runtime baseline.',
        ),
      );
    }

    var usedSnapshotFallback = false;
    var snapshotSeq = 0;
    var working = AuthorityRuntimeState.newBaseline(
      matchState: _initialMatchState,
      idCapacityPerPlayer: config.processedClientEventIdsCapacityPerPlayer,
    );

    try {
      final snapshot = await store.loadLatestSnapshot(matchId);
      if (snapshot != null) {
        final snapshotValidation = _validateSnapshot(matchId, snapshot);
        if (snapshotValidation == null) {
          snapshotSeq = snapshot.authoritativeSequence;
          working = AuthorityRuntimeState(
            matchState: snapshot.matchState,
            recentClientEventIdsByPlayer: _cloneRecentIds(
              snapshot.recentClientEventIdsByPlayer,
              config.processedClientEventIdsCapacityPerPlayer,
            ),
            lastAcceptedClientSeqByPlayer: Map<String, int>.from(
              snapshot.lastAcceptedClientSeqByPlayer,
            ),
            idCapacityPerPlayer:
                config.processedClientEventIdsCapacityPerPlayer,
          );
        } else {
          usedSnapshotFallback = true;
          snapshotSeq = 0;
          working = AuthorityRuntimeState.newBaseline(
            matchState: _initialMatchState,
            idCapacityPerPlayer:
                config.processedClientEventIdsCapacityPerPlayer,
          );
        }
      }
    } on Object catch (error) {
      return AuthorityRestoreResult(
        isSuccess: false,
        state: _state,
        snapshotSeq: 0,
        failure: AuthorityRestoreFailure(
          code: AuthorityRestoreFailureCode.storeReadFailed,
          message: 'Failed to load snapshot: $error',
        ),
      );
    }

    final tail = await _loadTail(matchId, snapshotSeq, working);
    if (!tail.isSuccess) {
      return tail;
    }

    _state = tail.state;
    return AuthorityRestoreResult(
      isSuccess: true,
      state: _state,
      snapshotSeq: snapshotSeq,
      usedSnapshotFallback: usedSnapshotFallback,
    );
  }

  Future<AuthorityRestoreResult> _loadTail(
    String matchId,
    int snapshotSeq,
    AuthorityRuntimeState working,
  ) async {
    List<PersistedAuthorityEvent> tail;
    try {
      tail = await store.loadAcceptedEventsAfter(matchId, snapshotSeq);
    } on Object catch (error) {
      return AuthorityRestoreResult(
        isSuccess: false,
        state: _state,
        snapshotSeq: snapshotSeq,
        failure: AuthorityRestoreFailure(
          code: AuthorityRestoreFailureCode.storeReadFailed,
          message: 'Failed to load accepted events: $error',
        ),
      );
    }

    var expected = snapshotSeq + 1;
    var current = working;
    for (final persisted in tail) {
      final validation = _validatePersistedEvent(
        persisted,
        expectedSequence: expected,
        matchId: matchId,
      );
      if (validation != null) {
        return AuthorityRestoreResult(
          isSuccess: false,
          state: _state,
          snapshotSeq: snapshotSeq,
          failure: validation,
        );
      }

      final reduce = tryReduceMatch(
        current.matchState,
        persisted.clientEvent.event,
      );
      if (!reduce.isSuccess) {
        return AuthorityRestoreResult(
          isSuccess: false,
          state: _state,
          snapshotSeq: snapshotSeq,
          failure: AuthorityRestoreFailure(
            code: AuthorityRestoreFailureCode.reducerReplayFailed,
            message: 'Accepted event replay failed during restore.',
          ),
        );
      }
      if (reduce.state.authoritativeSequence !=
          persisted.authoritativeSequence) {
        return AuthorityRestoreResult(
          isSuccess: false,
          state: _state,
          snapshotSeq: snapshotSeq,
          failure: const AuthorityRestoreFailure(
            code: AuthorityRestoreFailureCode.sequenceGap,
            message: 'Accepted event replay sequence mismatch.',
          ),
        );
      }

      current = _applyAcceptedMetadata(
        current._copyWith(matchState: reduce.state),
        persisted.playerId,
        persisted.clientSeq,
        persisted.clientEventId,
      );
      expected++;
    }

    return AuthorityRestoreResult(
      isSuccess: true,
      state: current,
      snapshotSeq: snapshotSeq,
    );
  }

  /// Applies one client event with durability and snapshot orchestration.
  Future<AuthorityApplyResult> apply(
    AuthorityRequestContext context,
    ClientEvent event,
  ) async {
    final contextFailure = _validateContext(context, event);
    if (contextFailure != null) {
      return _rejectedResult(
        contextFailure,
        null,
        mustFullyResync: false,
      );
    }

    final canonicalResult = _canonicalizeClientEvent(
      event,
      resolvedPlayerId: context.playerId,
      matchId: _state.matchState.config.matchId,
    );
    if (!canonicalResult.isSuccess) {
      return _rejectedResult(
        const AuthorityApplyFailure(
          code: AuthorityApplyFailureCode.invalidClientEvent,
          message: 'Unable to canonicalize client event for runtime apply.',
        ),
        ServerRejectReason.invalidClientEvent,
        mustFullyResync: false,
      );
    }
    final canonicalEvent = canonicalResult.value!;

    final membershipFailure = _validateMembership(canonicalEvent);
    if (membershipFailure != null) {
      return _rejectedResult(
        membershipFailure,
        ServerRejectReason.invalidClientEvent,
        mustFullyResync: false,
      );
    }

    final recent =
        _state.recentClientEventIdsByPlayer[canonicalEvent.playerId] ??
            const <String>[];
    final lastAccepted =
        _state.lastAcceptedClientSeqByPlayer[canonicalEvent.playerId];

    if (recent.contains(canonicalEvent.clientEventId)) {
      return AuthorityApplyResult(
        status: ServerApplyStatus.duplicateIgnored,
        state: _state,
        authoritativeSequence: _state.matchState.authoritativeSequence,
        lastAcceptedClientSeq: lastAccepted,
      );
    }

    if (lastAccepted != null && canonicalEvent.clientSeq <= lastAccepted) {
      return _rejectedResult(
        const AuthorityApplyFailure(
          code: AuthorityApplyFailureCode.outOfOrderClientSequence,
          message: 'clientSeq must be strictly greater than last accepted.',
        ),
        ServerRejectReason.outOfOrderOrDuplicate,
        mustFullyResync: true,
      );
    }

    final reduce = tryReduceMatch(_state.matchState, canonicalEvent.event);
    if (!reduce.isSuccess) {
      return _rejectedResult(
        const AuthorityApplyFailure(
          code: AuthorityApplyFailureCode.reducerRejected,
          message: 'Match reducer rejected event.',
        ),
        ServerRejectReason.reducerRejected,
        mustFullyResync: false,
      );
    }

    final acceptedRecord = ServerEventRecord(
      clientEvent: canonicalEvent,
      outcome: ServerApplyStatus.accepted,
      authoritativeSequence: reduce.state.authoritativeSequence,
    );
    final persisted = PersistedAuthorityEvent.fromAcceptedRecord(
      engineVersion: _state.matchState.engineVersion,
      matchId: _state.matchState.config.matchId,
      record: acceptedRecord,
    );

    try {
      await store.appendAcceptedEvent(
          _state.matchState.config.matchId, persisted);
    } on Object catch (error) {
      return _rejectedResult(
        AuthorityApplyFailure(
          code: AuthorityApplyFailureCode.durabilityFailure,
          message: 'Accepted event append failed: $error',
        ),
        null,
        mustFullyResync: true,
      );
    }

    var next = _state._copyWith(matchState: reduce.state);
    next = _applyAcceptedMetadata(
      next,
      canonicalEvent.playerId,
      canonicalEvent.clientSeq,
      canonicalEvent.clientEventId,
    );

    _state = next;

    final sequence = _state.matchState.authoritativeSequence;
    final shouldSnapshot =
        sequence > 0 && sequence % config.snapshotEveryAccepted == 0;
    if (shouldSnapshot) {
      await _saveSnapshotBestEffort();
    }

    return AuthorityApplyResult(
      status: ServerApplyStatus.accepted,
      state: _state,
      authoritativeSequence: sequence,
      lastAcceptedClientSeq:
          _state.lastAcceptedClientSeqByPlayer[canonicalEvent.playerId],
    );
  }

  Future<void> _saveSnapshotBestEffort() async {
    final snapshot = PersistedAuthoritySnapshot.fromRuntimeState(_state);
    try {
      await store.saveSnapshot(_state.matchState.config.matchId, snapshot);
    } on Object {
      // Accepted events are already durable; snapshot is a checkpoint only.
    }
  }

  AuthorityApplyResult _rejectedResult(
    AuthorityApplyFailure failure,
    ServerRejectReason? rejectReason, {
    required bool mustFullyResync,
  }) {
    return AuthorityApplyResult(
      status: ServerApplyStatus.rejected,
      state: _state,
      authoritativeSequence: _state.matchState.authoritativeSequence,
      failure: failure,
      rejectReason: rejectReason,
      mustFullyResync: mustFullyResync,
    );
  }

  AuthorityApplyFailure? _validateContext(
    AuthorityRequestContext context,
    ClientEvent event,
  ) {
    if (context.playerId.isEmpty) {
      return const AuthorityApplyFailure(
        code: AuthorityApplyFailureCode.invalidContext,
        message: 'Context playerId is required.',
      );
    }
    if (event.matchId != _state.matchState.config.matchId) {
      return const AuthorityApplyFailure(
        code: AuthorityApplyFailureCode.invalidClientEvent,
        message: 'Client event matchId does not match runtime match.',
      );
    }
    return null;
  }

  AuthorityApplyFailure? _validateMembership(ClientEvent event) {
    final hasPlayer = _state.matchState.players.any(
      (player) => player.playerId == event.playerId,
    );
    switch (event.event) {
      case JoinMatchEvent():
        return null;
      case LeaveMatchEvent():
      case SubmitMatchActionEvent():
      case StartMatchEvent():
        if (!hasPlayer) {
          return const AuthorityApplyFailure(
            code: AuthorityApplyFailureCode.playerNotInMatch,
            message: 'Player must be known in authoritative match state.',
          );
        }
        return null;
    }
  }

  DecodeResult<ClientEvent> _canonicalizeClientEvent(
    ClientEvent original, {
    required String resolvedPlayerId,
    required String matchId,
  }) {
    MatchEvent event;
    switch (original.event) {
      case JoinMatchEvent():
        event = JoinMatchEvent(playerId: resolvedPlayerId);
      case LeaveMatchEvent():
        event = LeaveMatchEvent(playerId: resolvedPlayerId);
      case SubmitMatchActionEvent(
          action: final action,
          clientSeq: final actionClientSeq,
        ):
        event = SubmitMatchActionEvent(
          playerId: resolvedPlayerId,
          action: action,
          clientSeq: actionClientSeq,
        );
      case StartMatchEvent():
        event = const StartMatchEvent();
    }

    return DecodeResult.success(
      ClientEvent(
        schemaVersion: original.schemaVersion,
        matchId: matchId,
        playerId: resolvedPlayerId,
        clientEventId: original.clientEventId,
        clientSeq: original.clientSeq,
        event: event,
      ),
    );
  }

  AuthorityRestoreFailure? _validateSnapshot(
    String matchId,
    PersistedAuthoritySnapshot snapshot,
  ) {
    if (snapshot.matchId != matchId) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.matchIdMismatch,
        message: 'Snapshot matchId does not match restore target.',
      );
    }
    if (snapshot.schemaVersion != _serializationSchemaV1) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.snapshotInvalid,
        message: 'Snapshot schemaVersion is unsupported.',
      );
    }
    if (snapshot.matchState.config.matchId != matchId ||
        snapshot.matchState.authoritativeSequence !=
            snapshot.authoritativeSequence) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.snapshotInvalid,
        message: 'Snapshot payload is inconsistent.',
      );
    }
    if (snapshot.engineVersion != snapshot.matchState.engineVersion) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.snapshotInvalid,
        message: 'Snapshot engineVersion mismatch.',
      );
    }
    return null;
  }

  AuthorityRestoreFailure? _validatePersistedEvent(
    PersistedAuthorityEvent event, {
    required int expectedSequence,
    required String matchId,
  }) {
    if (event.schemaVersion != _serializationSchemaV1) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.invalidPersistedEvent,
        message: 'Persisted event schemaVersion is unsupported.',
      );
    }
    if (event.matchId != matchId ||
        event.clientEvent.matchId != matchId ||
        event.serverRecord.clientEvent.matchId != matchId) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.matchIdMismatch,
        message: 'Persisted event matchId mismatch.',
      );
    }
    if (event.authoritativeSequence != expectedSequence) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.sequenceGap,
        message: 'Persisted accepted events must be strictly contiguous.',
      );
    }
    if (!event.serverRecord.accepted ||
        event.serverRecord.authoritativeSequence !=
            event.authoritativeSequence ||
        event.serverRecord.clientEvent.clientEventId != event.clientEventId ||
        event.serverRecord.clientEvent.clientSeq != event.clientSeq ||
        event.serverRecord.clientEvent.playerId != event.playerId) {
      return const AuthorityRestoreFailure(
        code: AuthorityRestoreFailureCode.invalidPersistedEvent,
        message: 'Persisted accepted event metadata is inconsistent.',
      );
    }
    return null;
  }

  static Map<String, List<String>> _cloneRecentIds(
    Map<String, List<String>> input,
    int capacity,
  ) {
    return input.map(
      (key, value) => MapEntry(key, _trimFifo(value, capacity)),
    );
  }

  static List<String> _trimFifo(List<String> values, int capacity) {
    if (values.length <= capacity) {
      return List<String>.from(values);
    }
    return values.sublist(values.length - capacity);
  }

  AuthorityRuntimeState _applyAcceptedMetadata(
    AuthorityRuntimeState current,
    String playerId,
    int clientSeq,
    String clientEventId,
  ) {
    final nextSeq = Map<String, int>.from(
      current.lastAcceptedClientSeqByPlayer,
    )..[playerId] = clientSeq;

    final nextRecent = <String, List<String>>{};
    for (final entry in current.recentClientEventIdsByPlayer.entries) {
      nextRecent[entry.key] = List<String>.from(entry.value);
    }
    final list = List<String>.from(nextRecent[playerId] ?? const <String>[]);
    if (!list.contains(clientEventId)) {
      list.add(clientEventId);
      if (list.length > current.idCapacityPerPlayer) {
        list.removeRange(0, list.length - current.idCapacityPerPlayer);
      }
    }
    nextRecent[playerId] = list;

    return current._copyWith(
      lastAcceptedClientSeqByPlayer: nextSeq,
      recentClientEventIdsByPlayer: nextRecent,
    );
  }
}
