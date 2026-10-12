import 'multiplayer_room_events.dart';
import 'multiplayer_room_types.dart';
import 'multiplayer_state.dart';

RoomState reduceRoom(RoomState state, RoomEvent event) {
  final result = tryReduceRoom(state, event);
  if (!result.isSuccess) throw StateError(result.failure!.message);
  return result.state;
}

/// Reapplies ordered room events from a deterministic room state.
RoomState replayRoomEvents(RoomState initial, List<RoomEvent> events) {
  var state = initial;
  for (final event in events) {
    state = reduceRoom(state, event);
  }
  return state;
}

/// Applies a room event without throwing for invalid transitions.
RoomReduceResult tryReduceRoom(RoomState state, RoomEvent event) {
  return switch (event) {
    JoinRoomEvent() => _join(state, event),
    LeaveRoomEvent() => _leave(state, event),
    StartRoomMatchEvent() => _start(state, event),
    CompleteRoomMatchEvent() => _complete(state, event),
  };
}

RoomReduceResult _join(RoomState state, JoinRoomEvent event) {
  if (state.status != RoomStatus.open) {
    return _roomFailure(
        state, RoomReduceFailureCode.roomNotOpen, 'Room is not open.');
  }
  if (state.members.any((member) => member.playerId == event.playerId)) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.duplicateMember,
      'Player has already joined this room.',
    );
  }
  if (event.playerId.trim().isEmpty) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.playerNotFound,
      'Player id must be non-empty.',
    );
  }
  if (state.members.length >= state.config.maxPlayers) {
    return _roomFailure(state, RoomReduceFailureCode.roomFull, 'Room is full.');
  }
  final members = <RoomMemberState>[
    ...state.members,
    RoomMemberState(playerId: event.playerId, joinOrder: state.nextJoinOrder),
  ];
  return RoomReduceResult(
    state: state.copyWith(
        members: members, nextJoinOrder: state.nextJoinOrder + 1),
  );
}

RoomReduceResult _leave(RoomState state, LeaveRoomEvent event) {
  if (state.status != RoomStatus.open) {
    return _roomFailure(
        state, RoomReduceFailureCode.roomNotOpen, 'Room is not open.');
  }
  if (!state.members.any((member) => member.playerId == event.playerId)) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.playerNotFound,
      'Player is not in this room.',
    );
  }
  final members = state.members
      .where((member) => member.playerId != event.playerId)
      .toList();
  return RoomReduceResult(
    state: state.copyWith(
      members: members,
      status: members.isEmpty ? RoomStatus.closed : null,
    ),
  );
}

RoomReduceResult _start(RoomState state, StartRoomMatchEvent event) {
  if (state.status != RoomStatus.open) {
    return _roomFailure(
        state, RoomReduceFailureCode.roomNotOpen, 'Room is not open.');
  }
  if (event.requestedByPlayerId != state.hostPlayerId) {
    return _roomFailure(
        state, RoomReduceFailureCode.notHost, 'Only the room host can start.');
  }
  if (state.members.length < state.config.minPlayers) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.notEnoughPlayers,
      'Room does not have enough players to start.',
    );
  }
  final matchConfig = state.config.matchConfig.copyWith(
    matchId: event.matchId,
    matchSeed: event.matchSeed,
    playerIds: state.members.map((member) => member.playerId).toList(),
  );
  try {
    final match = MatchState.newMatch(config: matchConfig);
    return RoomReduceResult(
      state: state.copyWith(status: RoomStatus.active, activeMatch: match),
    );
  } on Object catch (error) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.invalidMatch,
      'Unable to start match: $error',
    );
  }
}

RoomReduceResult _complete(RoomState state, CompleteRoomMatchEvent event) {
  if (state.status != RoomStatus.active || state.activeMatch == null) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.roomNotActive,
      'Room has no active match.',
    );
  }
  if (state.activeMatch!.config.matchId != event.matchId) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.matchIdMismatch,
      'Completed match id does not match the active match.',
    );
  }
  if (state.activeMatch!.phase != MatchPhase.finished) {
    return _roomFailure(
      state,
      RoomReduceFailureCode.matchNotFinished,
      'Active match has not finished.',
    );
  }
  return RoomReduceResult(
    state: state.copyWith(status: RoomStatus.open, clearActiveMatch: true),
  );
}

RoomReduceResult _roomFailure(
  RoomState state,
  RoomReduceFailureCode code,
  String message,
) {
  return RoomReduceResult(
    state: state,
    failure: RoomReduceFailure(code: code, message: message),
  );
}
