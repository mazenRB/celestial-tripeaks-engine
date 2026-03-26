part of '../tripeaks_engine.dart';

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
        final snapshotValidation =
            _authorityValidateSnapshot(matchId, snapshot);
        if (snapshotValidation == null) {
          snapshotSeq = snapshot.authoritativeSequence;
          working = AuthorityRuntimeState(
            matchState: snapshot.matchState,
            recentClientEventIdsByPlayer: _authorityCloneRecentIds(
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
      final validation = _authorityValidatePersistedEvent(
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
        _state.matchState.config.matchId,
        persisted,
      );
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
