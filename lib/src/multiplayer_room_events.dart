import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'multiplayer_room_types.dart';

sealed class RoomEvent {
  /// Creates a room event.
  const RoomEvent();

  /// Serializes this room event.
  Map<String, dynamic> toMap();

  /// Decodes a supported room event.
  static DecodeResult<RoomEvent> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<RoomEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported room event schema.',
        ),
      );
    }
    try {
      return switch (map['type']) {
        'join_room' => DecodeResult.success(
            JoinRoomEvent(playerId: map['playerId'] as String),
          ),
        'leave_room' => DecodeResult.success(
            LeaveRoomEvent(playerId: map['playerId'] as String),
          ),
        'start_room_match' => DecodeResult.success(
            StartRoomMatchEvent(
              requestedByPlayerId: map['requestedByPlayerId'] as String,
              matchId: map['matchId'] as String,
              matchSeed: map['matchSeed'] as int,
            ),
          ),
        'complete_room_match' => DecodeResult.success(
            CompleteRoomMatchEvent(matchId: map['matchId'] as String),
          ),
        _ => const DecodeResult<RoomEvent>.failure(
            DecodeFailure(
              code: DecodeFailureCode.unknownType,
              message: 'Unknown room event type.',
            ),
          ),
      };
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room event: $error',
        ),
      );
    }
  }
}

/// Adds a participant to an open room.
final class JoinRoomEvent extends RoomEvent {
  /// Creates a join event.
  const JoinRoomEvent({required this.playerId});

  /// Participant joining.
  final String playerId;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'join_room',
        'playerId': playerId,
      };
}

/// Removes a participant from an open room.
final class LeaveRoomEvent extends RoomEvent {
  /// Creates a leave event.
  const LeaveRoomEvent({required this.playerId});

  /// Participant leaving.
  final String playerId;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'leave_room',
        'playerId': playerId,
      };
}

/// Starts one match from the current fixed room roster.
final class StartRoomMatchEvent extends RoomEvent {
  /// Creates a room match-start event.
  const StartRoomMatchEvent({
    required this.requestedByPlayerId,
    required this.matchId,
    required this.matchSeed,
  });

  /// Room host requesting the start.
  final String requestedByPlayerId;

  /// Stable identifier for the resulting match.
  final String matchId;

  /// Shared seed for every participant.
  final int matchSeed;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'start_room_match',
        'requestedByPlayerId': requestedByPlayerId,
        'matchId': matchId,
        'matchSeed': matchSeed,
      };
}

/// Returns a finished room to the open state for a rematch.
final class CompleteRoomMatchEvent extends RoomEvent {
  /// Creates a completed-match event.
  const CompleteRoomMatchEvent({required this.matchId});

  /// Active match identifier expected by this event.
  final String matchId;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'complete_room_match',
        'matchId': matchId,
      };
}

/// Failure categories for room transitions.
enum RoomReduceFailureCode {
  roomNotOpen,
  roomNotActive,
  duplicateMember,
  playerNotFound,
  roomFull,
  notHost,
  notEnoughPlayers,
  invalidMatch,
  matchNotFinished,
  matchIdMismatch,
}

/// Typed room transition failure.
final class RoomReduceFailure {
  /// Creates a room failure.
  const RoomReduceFailure({required this.code, required this.message});

  /// Stable failure category.
  final RoomReduceFailureCode code;

  /// Human-readable diagnostic.
  final String message;
}

/// Room reducer result.
final class RoomReduceResult {
  /// Creates a room reducer result.
  const RoomReduceResult({required this.state, this.failure});

  /// Resulting room state, unchanged after rejection.
  final RoomState state;

  /// Rejection details, when present.
  final RoomReduceFailure? failure;

  /// Whether the room event was accepted.
  bool get isSuccess => failure == null;
}
