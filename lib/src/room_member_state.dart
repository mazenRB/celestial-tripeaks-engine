part of 'tripeaks_engine_internal.dart';

/// Deterministic room member state.
final class RoomMemberState {
  /// Creates room member state.
  const RoomMemberState({
    required this.memberId,
    required this.joinOrder,
    required this.status,
  });

  /// Stable room member identifier.
  final String memberId;

  /// Stable monotonic join order.
  final int joinOrder;

  /// Room membership status.
  final RoomMemberStatus status;

  RoomMemberState _copyWith({
    RoomMemberStatus? status,
  }) {
    return RoomMemberState(
      memberId: memberId,
      joinOrder: joinOrder,
      status: status ?? this.status,
    );
  }

  /// Serializes member state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_member_state',
      'memberId': memberId,
      'joinOrder': joinOrder,
      'status': status.name,
    };
  }

  /// Decodes member state from map without throwing.
  static DecodeResult<RoomMemberState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'room_member_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final memberId = map['memberId'];
    final joinOrder = map['joinOrder'];
    final status = map['status'];
    if (memberId is! String || joinOrder is! int || status is! String) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room member payload.',
        ),
      );
    }

    try {
      return DecodeResult.success(
        RoomMemberState(
          memberId: memberId,
          joinOrder: joinOrder,
          status: RoomMemberStatus.values.byName(status),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room member payload: $error',
        ),
      );
    }
  }
}
