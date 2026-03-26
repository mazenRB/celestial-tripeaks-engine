part of '../tripeaks_engine.dart';

/// Base type for authoritative match events.
sealed class MatchEvent {
  const MatchEvent();

  /// Stable event discriminator.
  String get eventType;

  /// Serializes event to map.
  Map<String, dynamic> toMap();
}

/// Player joins a room.
final class JoinMatchEvent extends MatchEvent {
  /// Creates join event.
  const JoinMatchEvent({required this.playerId});

  /// Joining player id.
  final String playerId;

  @override
  String get eventType => 'join';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
    };
  }
}

/// Player leaves a room.
final class LeaveMatchEvent extends MatchEvent {
  /// Creates leave event.
  const LeaveMatchEvent({required this.playerId});

  /// Leaving player id.
  final String playerId;

  @override
  String get eventType => 'leave';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
    };
  }
}

/// Starts a waiting match.
final class StartMatchEvent extends MatchEvent {
  /// Creates start event.
  const StartMatchEvent();

  @override
  String get eventType => 'start';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
    };
  }
}

/// Submits one action attempt for one player.
final class SubmitMatchActionEvent extends MatchEvent {
  /// Creates submit action event.
  const SubmitMatchActionEvent({
    required this.playerId,
    required this.action,
    this.clientSeq,
  });

  /// Submitting player id.
  final String playerId;

  /// Submitted session action.
  final TriPeaksSessionAction action;

  /// Optional client-side sequence marker.
  final int? clientSeq;

  @override
  String get eventType => 'submit_action';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
      'action': sessionActionToMap(action),
      if (clientSeq case final value?) 'clientSeq': value,
    };
  }
}

/// Decodes one match event from map without throwing.
DecodeResult<MatchEvent> tryDecodeMatchEvent(Map<String, dynamic> map) {
  if (map['schemaVersion'] != _serializationSchemaV1) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unsupportedSchemaVersion,
        message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
      ),
    );
  }
  if (map['type'] != 'match_event') {
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
    case 'join':
      final playerId = map['playerId'];
      if (playerId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'join requires string playerId.',
          ),
        );
      }
      return DecodeResult.success(JoinMatchEvent(playerId: playerId));

    case 'leave':
      final playerId = map['playerId'];
      if (playerId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'leave requires string playerId.',
          ),
        );
      }
      return DecodeResult.success(LeaveMatchEvent(playerId: playerId));

    case 'start':
      return const DecodeResult.success(StartMatchEvent());

    case 'submit_action':
      final playerId = map['playerId'];
      final actionMap = map['action'];
      final clientSeq = map['clientSeq'];
      if (playerId is! String || actionMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'submit_action requires playerId and action map.',
          ),
        );
      }
      if (clientSeq != null && clientSeq is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'clientSeq must be int when present.',
          ),
        );
      }
      final decodedAction = tryDecodeSessionAction(actionMap);
      if (!decodedAction.isSuccess) {
        return DecodeResult.failure(decodedAction.error!);
      }
      return DecodeResult.success(
        SubmitMatchActionEvent(
          playerId: playerId,
          action: decodedAction.value!,
          clientSeq: clientSeq as int?,
        ),
      );

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown match event type "$eventType".',
        ),
      );
  }
}
