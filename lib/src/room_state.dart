part of 'tripeaks_engine_internal.dart';

/// Deterministic room state used for canonical match bootstrap.
final class RoomState {
  /// Creates a room state.
  const RoomState({
    required this.schemaVersion,
    required this.engineVersion,
    required this.config,
    required this.roomStatus,
    required this.authoritativeSequence,
    required this.members,
    required this.hostMemberId,
    required this.bootstrappedMatchCount,
    this.activeMatchId,
  });

  /// Creates initial open room state.
  factory RoomState.newRoom({required RoomConfig config}) {
    return RoomState(
      schemaVersion: _serializationSchemaV1,
      engineVersion: config.engineVersion,
      config: config,
      roomStatus: RoomStatus.open,
      authoritativeSequence: 0,
      members: const <RoomMemberState>[],
      hostMemberId: null,
      bootstrappedMatchCount: 0,
      activeMatchId: null,
    );
  }

  /// Serialization schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Room configuration.
  final RoomConfig config;

  /// Room lifecycle status.
  final RoomStatus roomStatus;

  /// Authoritative total ordering sequence.
  final int authoritativeSequence;

  /// Members in stable join order.
  final List<RoomMemberState> members;

  /// Current deterministic host member id.
  final String? hostMemberId;

  /// Count of bootstrapped matches for this room.
  final int bootstrappedMatchCount;

  /// Currently active match id when a match is in progress.
  final String? activeMatchId;

  RoomState _copyWith({
    RoomStatus? roomStatus,
    int? authoritativeSequence,
    List<RoomMemberState>? members,
    String? hostMemberId,
    bool clearHostMemberId = false,
    int? bootstrappedMatchCount,
    String? activeMatchId,
    bool clearActiveMatchId = false,
  }) {
    return RoomState(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      config: config,
      roomStatus: roomStatus ?? this.roomStatus,
      authoritativeSequence:
          authoritativeSequence ?? this.authoritativeSequence,
      members: List<RoomMemberState>.unmodifiable(members ?? this.members),
      hostMemberId:
          clearHostMemberId ? null : (hostMemberId ?? this.hostMemberId),
      bootstrappedMatchCount:
          bootstrappedMatchCount ?? this.bootstrappedMatchCount,
      activeMatchId:
          clearActiveMatchId ? null : (activeMatchId ?? this.activeMatchId),
    );
  }

  /// Serializes room state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'room_state',
      'engineVersion': engineVersion,
      'config': config.toMap(),
      'roomStatus': roomStatus.name,
      'authoritativeSequence': authoritativeSequence,
      'members':
          members.map((member) => member.toMap()).toList(growable: false),
      'bootstrappedMatchCount': bootstrappedMatchCount,
      if (hostMemberId case final value?) 'hostMemberId': value,
      if (activeMatchId case final value?) 'activeMatchId': value,
    };
  }

  /// Decodes room state from map without throwing.
  static DecodeResult<RoomState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'room_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final engineVersion = map['engineVersion'];
    final configMap = map['config'];
    final roomStatus = map['roomStatus'];
    final authoritativeSequence = map['authoritativeSequence'];
    final membersRaw = map['members'];
    final hostMemberId = map['hostMemberId'];
    final bootstrappedMatchCount = map['bootstrappedMatchCount'];
    final activeMatchId = map['activeMatchId'];
    if (engineVersion is! int ||
        configMap is! Map<String, dynamic> ||
        roomStatus is! String ||
        authoritativeSequence is! int ||
        membersRaw is! List<dynamic> ||
        bootstrappedMatchCount is! int ||
        (hostMemberId != null && hostMemberId is! String) ||
        (activeMatchId != null && activeMatchId is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room state payload.',
        ),
      );
    }

    final config = RoomConfig.tryFromMap(configMap);
    if (!config.isSuccess) {
      return DecodeResult.failure(config.error!);
    }

    final members = <RoomMemberState>[];
    for (final raw in membersRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'members items must be maps.',
          ),
        );
      }
      final member = RoomMemberState.tryFromMap(raw);
      if (!member.isSuccess) {
        return DecodeResult.failure(member.error!);
      }
      members.add(member.value!);
    }

    try {
      return DecodeResult.success(
        RoomState(
          schemaVersion: _serializationSchemaV1,
          engineVersion: engineVersion,
          config: config.value!,
          roomStatus: RoomStatus.values.byName(roomStatus),
          authoritativeSequence: authoritativeSequence,
          members: List<RoomMemberState>.unmodifiable(members),
          hostMemberId: hostMemberId as String?,
          bootstrappedMatchCount: bootstrappedMatchCount,
          activeMatchId: activeMatchId as String?,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room state payload: $error',
        ),
      );
    }
  }
}
