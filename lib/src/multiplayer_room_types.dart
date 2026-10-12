import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'multiplayer_config.dart';
import 'multiplayer_state.dart';

final class RoomConfig {
  /// Creates room settings around a match template.
  const RoomConfig({
    required this.roomId,
    required this.hostPlayerId,
    required this.matchConfig,
    this.minPlayers = 2,
    int? maxPlayers,
  }) : _maxPlayers = maxPlayers;

  /// Stable identifier assigned by the integrating application.
  final String roomId;

  /// Initial host and first room member.
  final String hostPlayerId;

  /// Match settings reused with the final room roster and shared seed.
  final MatchConfig matchConfig;

  /// Minimum joined players required to start.
  final int minPlayers;

  final int? _maxPlayers;

  /// Maximum roster size; Async rooms default to two participants.
  int get maxPlayers =>
      _maxPlayers ?? (matchConfig.matchMode == MatchMode.asynchronous ? 2 : 8);

  /// Serializes room settings.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_room_config',
        'roomId': roomId,
        'hostPlayerId': hostPlayerId,
        'matchConfig': matchConfig.toMap(),
        'minPlayers': minPlayers,
        'maxPlayers': maxPlayers,
      };

  /// Decodes room settings.
  static DecodeResult<RoomConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<RoomConfig>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported room config schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_room_config') {
      return const DecodeResult<RoomConfig>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown room config type.',
        ),
      );
    }
    try {
      final matchConfig = MatchConfig.tryFromMap(
        map['matchConfig'] as Map<String, dynamic>,
      );
      if (!matchConfig.isSuccess) {
        return DecodeResult.failure(matchConfig.error!);
      }
      return DecodeResult.success(
        RoomConfig(
          roomId: map['roomId'] as String,
          hostPlayerId: map['hostPlayerId'] as String,
          matchConfig: matchConfig.value!,
          minPlayers: map['minPlayers'] as int,
          maxPlayers: map['maxPlayers'] as int,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room config: $error',
        ),
      );
    }
  }
}

/// Lifecycle status of a room.
enum RoomStatus { open, active, closed }

/// State of a participant currently in a room.
final class RoomMemberState {
  /// Creates a room member record.
  const RoomMemberState({required this.playerId, required this.joinOrder});

  /// Stable application-provided participant identifier.
  final String playerId;

  /// Monotonic room-local ordering used for deterministic host transfer.
  final int joinOrder;

  /// Serializes this member.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_room_member',
        'playerId': playerId,
        'joinOrder': joinOrder,
      };

  /// Decodes a member record.
  static DecodeResult<RoomMemberState> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<RoomMemberState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported room member schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_room_member') {
      return const DecodeResult<RoomMemberState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown room member type.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        RoomMemberState(
          playerId: map['playerId'] as String,
          joinOrder: map['joinOrder'] as int,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room member: $error',
        ),
      );
    }
  }
}

/// Deterministic room membership and active-match snapshot.
final class RoomState {
  RoomState._({
    required this.config,
    required this.status,
    required this.members,
    required this.nextJoinOrder,
    this.activeMatch,
  });

  /// Opens a room with its configured host as the first member.
  factory RoomState.newRoom({required RoomConfig config}) {
    _validateRoomConfig(config);
    final fixedMatchConfig = config.matchConfig.copyWith(
      playerIds: List<String>.unmodifiable(config.matchConfig.playerIds),
      roundTimerConfig: RoundTimerConfig(
        enabled: config.matchConfig.roundTimerConfig.enabled,
        durationsSecondsByRound: List<int>.unmodifiable(
          config.matchConfig.roundTimerConfig.durationsSecondsByRound,
        ),
      ),
    );
    final fixedConfig = RoomConfig(
      roomId: config.roomId,
      hostPlayerId: config.hostPlayerId,
      matchConfig: fixedMatchConfig,
      minPlayers: config.minPlayers,
      maxPlayers: config.maxPlayers,
    );
    return RoomState._(
      config: fixedConfig,
      status: RoomStatus.open,
      members: List<RoomMemberState>.unmodifiable(<RoomMemberState>[
        RoomMemberState(playerId: fixedConfig.hostPlayerId, joinOrder: 0),
      ]),
      nextJoinOrder: 1,
    );
  }

  /// Room configuration.
  final RoomConfig config;

  /// Current room lifecycle status.
  final RoomStatus status;

  /// Joined members in deterministic join order.
  final List<RoomMemberState> members;

  /// Next available monotonic join order.
  final int nextJoinOrder;

  /// Active match while the room is in [RoomStatus.active].
  final MatchState? activeMatch;

  /// Current host, or `null` after the room closes.
  String? get hostPlayerId => members.isEmpty ? null : members.first.playerId;

  /// Serializes room, roster, and active match state.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_room_state',
        'config': config.toMap(),
        'status': status.name,
        'members': members.map((member) => member.toMap()).toList(),
        'nextJoinOrder': nextJoinOrder,
        if (activeMatch case final match?) 'activeMatch': match.toMap(),
      };

  /// Decodes a room snapshot.
  static DecodeResult<RoomState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<RoomState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported room state schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_room_state') {
      return const DecodeResult<RoomState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown room state type.',
        ),
      );
    }
    try {
      final config = RoomConfig.tryFromMap(
        map['config'] as Map<String, dynamic>,
      );
      if (!config.isSuccess) return DecodeResult.failure(config.error!);
      final members = <RoomMemberState>[];
      for (final raw in map['members'] as List<dynamic>) {
        final member = RoomMemberState.tryFromMap(
          raw as Map<String, dynamic>,
        );
        if (!member.isSuccess) return DecodeResult.failure(member.error!);
        members.add(member.value!);
      }
      MatchState? activeMatch;
      final active = map['activeMatch'];
      if (active != null) {
        final decoded = MatchState.tryFromMap(active as Map<String, dynamic>);
        if (!decoded.isSuccess) return DecodeResult.failure(decoded.error!);
        activeMatch = decoded.value!;
      }
      final state = RoomState._(
        config: config.value!,
        status: RoomStatus.values.byName(map['status'] as String),
        members: List<RoomMemberState>.unmodifiable(members),
        nextJoinOrder: map['nextJoinOrder'] as int,
        activeMatch: activeMatch,
      );
      _validateRoomConfig(state.config);
      if (state.status == RoomStatus.active && state.activeMatch == null ||
          state.status != RoomStatus.active && state.activeMatch != null ||
          state.members.map((member) => member.playerId).toSet().length !=
              state.members.length ||
          state.members.length > state.config.maxPlayers ||
          (state.members.isNotEmpty &&
              state.members.first.joinOrder !=
                  state.members.map((member) => member.joinOrder).reduce(
                        (a, b) => a < b ? a : b,
                      ))) {
        throw const FormatException('Inconsistent room state.');
      }
      if ((state.status != RoomStatus.closed && state.members.isEmpty) ||
          (state.status == RoomStatus.closed && state.members.isNotEmpty) ||
          state.members.any((member) => member.joinOrder < 0) ||
          state.members.indexed.any(
            (entry) =>
                entry.$1 > 0 &&
                state.members[entry.$1 - 1].joinOrder >= entry.$2.joinOrder,
          ) ||
          (state.members.isNotEmpty &&
              state.nextJoinOrder <= state.members.last.joinOrder)) {
        throw const FormatException('Invalid room member ordering.');
      }
      if (state.status == RoomStatus.active &&
          state.members.length < state.config.minPlayers) {
        throw const FormatException('Active room has too few participants.');
      }
      if (state.activeMatch case final match?) {
        final matchRoster = match.config.playerIds;
        final roomRoster =
            state.members.map((member) => member.playerId).toList();
        if (match.config.matchMode != state.config.matchConfig.matchMode ||
            matchRoster.length != roomRoster.length ||
            !List.generate(roomRoster.length, (index) => index).every(
              (index) => matchRoster[index] == roomRoster[index],
            )) {
          throw const FormatException(
              'Active match roster does not match room.');
        }
      }
      return DecodeResult.success(state);
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room state: $error',
        ),
      );
    }
  }

  /// Returns a room state copy with selected values replaced.
  RoomState copyWith({
    RoomStatus? status,
    List<RoomMemberState>? members,
    int? nextJoinOrder,
    MatchState? activeMatch,
    bool clearActiveMatch = false,
  }) {
    return RoomState._(
      config: config,
      status: status ?? this.status,
      members: List<RoomMemberState>.unmodifiable(members ?? this.members),
      nextJoinOrder: nextJoinOrder ?? this.nextJoinOrder,
      activeMatch: clearActiveMatch ? null : activeMatch ?? this.activeMatch,
    );
  }
}

void _validateRoomConfig(RoomConfig config) {
  if (config.roomId.trim().isEmpty || config.hostPlayerId.trim().isEmpty) {
    throw ArgumentError('Room id and host id must be non-empty.');
  }
  if (config.minPlayers < 2 || config.maxPlayers < config.minPlayers) {
    throw ArgumentError('Room player limits are invalid.');
  }
  if (config.matchConfig.matchMode == MatchMode.asynchronous &&
      config.maxPlayers != 2) {
    throw ArgumentError('Async rooms support exactly two players.');
  }
}
