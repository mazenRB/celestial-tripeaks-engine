part of 'tripeaks_engine_internal.dart';

/// Base type for deterministic room events.
sealed class RoomEvent {
  const RoomEvent();

  /// Stable event discriminator.
  String get eventType;

  /// Serializes event to map.
  Map<String, dynamic> toMap();
}

/// Deterministically joins or rejoins a room.
final class JoinRoomEvent extends RoomEvent {
  /// Creates a join event.
  const JoinRoomEvent({required this.memberId});

  /// Joining member id.
  final String memberId;

  @override
  String get eventType => 'join_room';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_event',
      'eventType': eventType,
      'memberId': memberId,
    };
  }
}

/// Leaves a room before a match starts.
final class LeaveRoomEvent extends RoomEvent {
  /// Creates a leave event.
  const LeaveRoomEvent({required this.memberId});

  /// Leaving member id.
  final String memberId;

  @override
  String get eventType => 'leave_room';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_event',
      'eventType': eventType,
      'memberId': memberId,
    };
  }
}

/// Bootstraps a canonical live match from the room.
final class StartRoomMatchEvent extends RoomEvent {
  /// Creates a start event.
  const StartRoomMatchEvent({
    required this.requestedByMemberId,
    required this.matchId,
    required this.matchSeed,
  });

  /// Member requesting the start.
  final String requestedByMemberId;

  /// Caller-supplied live match id.
  final String matchId;

  /// Caller-supplied deterministic match seed.
  final int matchSeed;

  @override
  String get eventType => 'start_room_match';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_event',
      'eventType': eventType,
      'requestedByMemberId': requestedByMemberId,
      'matchId': matchId,
      'matchSeed': matchSeed,
    };
  }
}

/// Completes the active match and reopens the room for a later rematch.
final class CompleteRoomMatchEvent extends RoomEvent {
  /// Creates a completion event.
  const CompleteRoomMatchEvent({required this.matchId});

  /// Completed live match id.
  final String matchId;

  @override
  String get eventType => 'complete_room_match';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_event',
      'eventType': eventType,
      'matchId': matchId,
    };
  }
}

/// Decodes a room event from map without throwing.
DecodeResult<RoomEvent> tryDecodeRoomEvent(Map<String, dynamic> map) {
  if (map['schemaVersion'] != _serializationSchemaV1) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unsupportedSchemaVersion,
        message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
      ),
    );
  }
  if (map['type'] != 'room_event') {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unknownType,
        message: 'Unknown type ${map['type']}.',
      ),
    );
  }

  final eventType = map['eventType'];
  if (eventType is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'eventType must be a string.',
      ),
    );
  }

  switch (eventType) {
    case 'join_room':
      final memberId = map['memberId'];
      if (memberId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'join_room requires string memberId.',
          ),
        );
      }
      return DecodeResult.success(JoinRoomEvent(memberId: memberId));

    case 'leave_room':
      final memberId = map['memberId'];
      if (memberId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'leave_room requires string memberId.',
          ),
        );
      }
      return DecodeResult.success(LeaveRoomEvent(memberId: memberId));

    case 'start_room_match':
      final requestedByMemberId = map['requestedByMemberId'];
      final matchId = map['matchId'];
      final matchSeed = map['matchSeed'];
      if (requestedByMemberId is! String ||
          matchId is! String ||
          matchSeed is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'start_room_match requires requester, matchId, matchSeed.',
          ),
        );
      }
      return DecodeResult.success(
        StartRoomMatchEvent(
          requestedByMemberId: requestedByMemberId,
          matchId: matchId,
          matchSeed: matchSeed,
        ),
      );

    case 'complete_room_match':
      final matchId = map['matchId'];
      if (matchId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'complete_room_match requires string matchId.',
          ),
        );
      }
      return DecodeResult.success(CompleteRoomMatchEvent(matchId: matchId));

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown room event type "$eventType".',
        ),
      );
  }
}
