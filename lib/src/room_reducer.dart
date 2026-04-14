part of 'tripeaks_engine_internal.dart';

/// Applies one room [event] to [state] using a pure deterministic reducer.
RoomReduceResult tryReduceRoom(RoomState state, RoomEvent event) {
  switch (event) {
    case JoinRoomEvent(memberId: final memberId):
      if (state.roomStatus == RoomStatus.closed) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.roomClosed,
            message: 'Room is closed.',
          ),
        );
      }
      if (state.roomStatus == RoomStatus.matchInProgress) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.matchAlreadyInProgress,
            message: 'Room membership is frozen while a match is active.',
          ),
        );
      }

      final existingIndex = _roomMemberIndex(state.members, memberId);
      final joinedCount = _joinedMembers(state.members).length;
      if (existingIndex >= 0) {
        final existing = state.members[existingIndex];
        if (existing.status == RoomMemberStatus.joined) {
          return RoomReduceResult(
            state: state,
            failure: const RoomReduceFailure(
              code: RoomReduceFailureCode.memberAlreadyJoined,
              message: 'Member already joined.',
            ),
          );
        }
        if (joinedCount >= state.config.maxMembers) {
          return RoomReduceResult(
            state: state,
            failure: const RoomReduceFailure(
              code: RoomReduceFailureCode.roomFull,
              message: 'Room is full.',
            ),
          );
        }
        final nextMembers = state.members.toList(growable: false);
        nextMembers[existingIndex] = existing._copyWith(
          status: RoomMemberStatus.joined,
        );
        final nextHost =
            state.hostMemberId ?? _computeHostMemberId(nextMembers);
        return RoomReduceResult(
          state: state._copyWith(
            members: nextMembers,
            hostMemberId: nextHost,
            roomStatus: RoomStatus.open,
            authoritativeSequence: state.authoritativeSequence + 1,
          ),
        );
      }

      if (joinedCount >= state.config.maxMembers) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.roomFull,
            message: 'Room is full.',
          ),
        );
      }

      final nextMembers = <RoomMemberState>[
        ...state.members,
        RoomMemberState(
          memberId: memberId,
          joinOrder: state.members.length + 1,
          status: RoomMemberStatus.joined,
        ),
      ];
      return RoomReduceResult(
        state: state._copyWith(
          members: nextMembers,
          hostMemberId: state.hostMemberId ?? memberId,
          roomStatus: RoomStatus.open,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case LeaveRoomEvent(memberId: final memberId):
      if (state.roomStatus == RoomStatus.matchInProgress) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.matchAlreadyInProgress,
            message: 'Cannot change room membership while a match is active.',
          ),
        );
      }
      final index = _roomMemberIndex(state.members, memberId);
      if (index < 0) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.memberNotFound,
            message: 'Member not found.',
          ),
        );
      }

      final member = state.members[index];
      if (member.status != RoomMemberStatus.joined) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.memberNotJoined,
            message: 'Member is not currently joined.',
          ),
        );
      }

      final nextMembers = state.members.toList(growable: false);
      nextMembers[index] = member._copyWith(status: RoomMemberStatus.left);
      final nextHost = _computeHostMemberId(nextMembers);
      final nextRoomStatus =
          nextHost == null ? RoomStatus.closed : RoomStatus.open;
      return RoomReduceResult(
        state: state._copyWith(
          members: nextMembers,
          hostMemberId: nextHost,
          clearHostMemberId: nextHost == null,
          roomStatus: nextRoomStatus,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case StartRoomMatchEvent(
        requestedByMemberId: final requestedByMemberId,
        matchId: final matchId,
        matchSeed: final matchSeed,
      ):
      if (state.roomStatus == RoomStatus.closed) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.roomClosed,
            message: 'Room is closed.',
          ),
        );
      }
      if (state.roomStatus == RoomStatus.matchInProgress) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.matchAlreadyInProgress,
            message: 'A match is already in progress.',
          ),
        );
      }
      if (state.hostMemberId != requestedByMemberId) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.hostRequired,
            message: 'Only the deterministic host may start the room.',
          ),
        );
      }

      final joinedMembers = _joinedMembers(state.members);
      if (joinedMembers.length < state.config.minMembers ||
          joinedMembers.length > state.config.maxMembers) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.invalidStartMembers,
            message: 'Joined member count does not satisfy start rules.',
          ),
        );
      }

      final matchConfig = MatchConfig(
        matchMode: state.config.matchMode,
        matchId: matchId,
        matchSeed: matchSeed,
        maxPlayers: joinedMembers.length,
        ruleset: state.config.ruleset,
        scoreConfig: state.config.scoreConfig,
        roundRulesConfig: state.config.roundRulesConfig,
        roundTimerConfig: state.config.roundTimerConfig,
        undoConfig: state.config.undoConfig,
        streakConfig: state.config.streakConfig,
        strikeTimerConfig: state.config.strikeTimerConfig,
        bonusSlotsConfig: state.config.bonusSlotsConfig,
        dealPolicyConfig: state.config.dealPolicyConfig,
        engineVersion: state.engineVersion,
      );
      final matchState = MatchState.newMatch(
        config: matchConfig,
        playerIds: joinedMembers.map((member) => member.memberId).toList(),
      );
      final matchOrdinal = state.bootstrappedMatchCount + 1;
      final bootstrap = MatchBootstrap(
        schemaVersion: _serializationSchemaV1,
        engineVersion: state.engineVersion,
        roomId: state.config.roomId,
        matchId: matchId,
        matchOrdinal: matchOrdinal,
        matchConfig: matchConfig,
        matchState: matchState,
      );

      return RoomReduceResult(
        state: state._copyWith(
          roomStatus: RoomStatus.matchInProgress,
          activeMatchId: matchId,
          bootstrappedMatchCount: matchOrdinal,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
        bootstrap: bootstrap,
      );

    case CompleteRoomMatchEvent(matchId: final matchId):
      if (state.roomStatus != RoomStatus.matchInProgress ||
          state.activeMatchId == null) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.matchNotInProgress,
            message: 'No room match is currently active.',
          ),
        );
      }
      if (state.activeMatchId != matchId) {
        return RoomReduceResult(
          state: state,
          failure: const RoomReduceFailure(
            code: RoomReduceFailureCode.activeMatchIdMismatch,
            message: 'Completed match does not match the active room match.',
          ),
        );
      }

      final nextHost = _computeHostMemberId(state.members);
      final nextRoomStatus =
          nextHost == null ? RoomStatus.closed : RoomStatus.open;
      return RoomReduceResult(
        state: state._copyWith(
          roomStatus: nextRoomStatus,
          hostMemberId: nextHost,
          clearHostMemberId: nextHost == null,
          clearActiveMatchId: true,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );
  }
}

int _roomMemberIndex(List<RoomMemberState> members, String memberId) {
  for (var i = 0; i < members.length; i++) {
    if (members[i].memberId == memberId) {
      return i;
    }
  }
  return -1;
}

List<RoomMemberState> _joinedMembers(List<RoomMemberState> members) {
  return members
      .where((member) => member.status == RoomMemberStatus.joined)
      .toList(growable: false);
}

String? _computeHostMemberId(List<RoomMemberState> members) {
  String? hostMemberId;
  var bestJoinOrder = 1 << 30;
  for (final member in members) {
    if (member.status != RoomMemberStatus.joined) {
      continue;
    }
    if (member.joinOrder < bestJoinOrder) {
      bestJoinOrder = member.joinOrder;
      hostMemberId = member.memberId;
    }
  }
  return hostMemberId;
}

/// Deterministically applies ordered [events] from [initial] room state.
RoomState replayRoomEvents(RoomState initial, List<RoomEvent> events) {
  var state = initial;
  for (final event in events) {
    final result = tryReduceRoom(state, event);
    state = result.state;
  }
  return state;
}
