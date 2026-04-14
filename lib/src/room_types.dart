part of 'tripeaks_engine_internal.dart';

/// Multiplayer room mode.
enum MatchMode {
  realtime,
  async,
}

/// Room lifecycle status.
enum RoomStatus {
  open,
  matchInProgress,
  closed,
}

/// Room membership lifecycle status.
enum RoomMemberStatus {
  joined,
  left,
}

/// Deterministic room configuration.
final class RoomConfig {
  /// Creates a room configuration.
  const RoomConfig({
    required this.roomId,
    required this.matchMode,
    required this.minMembers,
    required this.maxMembers,
    this.ruleset = TriPeaksRuleset.threeRounds,
    this.scoreConfig = const ScoreConfig(),
    this.roundRulesConfig = const RoundRulesConfig(),
    this.roundTimerConfig = const RoundTimerConfig(),
    this.undoConfig = const UndoConfig(),
    this.streakConfig = const StreakConfig(),
    this.strikeTimerConfig = const StrikeTimerConfig(),
    this.bonusSlotsConfig = const BonusSlotsConfig(),
    this.dealPolicyConfig = const DealPolicyConfig(),
    this.engineVersion = 1,
  })  : assert(minMembers > 0),
        assert(maxMembers >= minMembers);

  /// Stable room identifier.
  final String roomId;

  /// Match mode for bootstrapped matches.
  final MatchMode matchMode;

  /// Minimum joined members required to start.
  final int minMembers;

  /// Maximum joined members allowed in the room.
  final int maxMembers;

  /// Shared session ruleset.
  final TriPeaksRuleset ruleset;

  /// Shared score configuration.
  final ScoreConfig scoreConfig;

  /// Shared round rules configuration.
  final RoundRulesConfig roundRulesConfig;

  /// Shared round timer configuration.
  final RoundTimerConfig roundTimerConfig;

  /// Shared undo configuration.
  final UndoConfig undoConfig;

  /// Shared streak configuration.
  final StreakConfig streakConfig;

  /// Shared strike timer configuration.
  final StrikeTimerConfig strikeTimerConfig;

  /// Shared bonus slots configuration.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Shared deal policy configuration.
  final DealPolicyConfig dealPolicyConfig;

  /// Engine version metadata.
  final int engineVersion;

  /// Serializes config to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'room_config',
      'roomId': roomId,
      'matchMode': matchMode.name,
      'minMembers': minMembers,
      'maxMembers': maxMembers,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'dealPolicyConfig': dealPolicyConfig.toMap(),
      'engineVersion': engineVersion,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<RoomConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'room_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final roomId = map['roomId'];
    final matchMode = map['matchMode'];
    final minMembers = map['minMembers'];
    final maxMembers = map['maxMembers'];
    final engineVersion = map['engineVersion'];
    final rulesetMap = map['ruleset'];
    final scoreMap = map['scoreConfig'];
    final roundRulesMap = map['roundRulesConfig'];
    final roundTimerMap = map['roundTimerConfig'];
    final undoMap = map['undoConfig'];
    final streakMap = map['streakConfig'];
    final strikeTimerMap = map['strikeTimerConfig'];
    final bonusSlotsMap = map['bonusSlotsConfig'];
    final dealPolicyMap = map['dealPolicyConfig'];
    if (roomId is! String ||
        matchMode is! String ||
        minMembers is! int ||
        maxMembers is! int ||
        engineVersion is! int ||
        rulesetMap is! Map<String, dynamic> ||
        scoreMap is! Map<String, dynamic> ||
        roundRulesMap is! Map<String, dynamic> ||
        roundTimerMap is! Map<String, dynamic> ||
        undoMap is! Map<String, dynamic> ||
        streakMap is! Map<String, dynamic> ||
        strikeTimerMap is! Map<String, dynamic> ||
        bonusSlotsMap is! Map<String, dynamic> ||
        dealPolicyMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room config payload.',
        ),
      );
    }

    final ruleset = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!ruleset.isSuccess) {
      return DecodeResult.failure(ruleset.error!);
    }
    final scoreConfig = ScoreConfig.tryFromMap(scoreMap);
    if (!scoreConfig.isSuccess) {
      return DecodeResult.failure(scoreConfig.error!);
    }
    final roundRulesConfig = RoundRulesConfig.tryFromMap(roundRulesMap);
    if (!roundRulesConfig.isSuccess) {
      return DecodeResult.failure(roundRulesConfig.error!);
    }
    final roundTimerConfig = RoundTimerConfig.tryFromMap(roundTimerMap);
    if (!roundTimerConfig.isSuccess) {
      return DecodeResult.failure(roundTimerConfig.error!);
    }
    final undoConfig = UndoConfig.tryFromMap(undoMap);
    if (!undoConfig.isSuccess) {
      return DecodeResult.failure(undoConfig.error!);
    }
    final streakConfig = StreakConfig.tryFromMap(streakMap);
    if (!streakConfig.isSuccess) {
      return DecodeResult.failure(streakConfig.error!);
    }
    final strikeTimerConfig = StrikeTimerConfig.tryFromMap(strikeTimerMap);
    if (!strikeTimerConfig.isSuccess) {
      return DecodeResult.failure(strikeTimerConfig.error!);
    }
    final bonusSlotsConfig = BonusSlotsConfig.tryFromMap(bonusSlotsMap);
    if (!bonusSlotsConfig.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfig.error!);
    }
    final dealPolicyConfig = DealPolicyConfig.tryFromMap(dealPolicyMap);
    if (!dealPolicyConfig.isSuccess) {
      return DecodeResult.failure(dealPolicyConfig.error!);
    }

    try {
      return DecodeResult.success(
        RoomConfig(
          roomId: roomId,
          matchMode: MatchMode.values.byName(matchMode),
          minMembers: minMembers,
          maxMembers: maxMembers,
          ruleset: ruleset.value!,
          scoreConfig: scoreConfig.value!,
          roundRulesConfig: roundRulesConfig.value!,
          roundTimerConfig: roundTimerConfig.value!,
          undoConfig: undoConfig.value!,
          streakConfig: streakConfig.value!,
          strikeTimerConfig: strikeTimerConfig.value!,
          bonusSlotsConfig: bonusSlotsConfig.value!,
          dealPolicyConfig: dealPolicyConfig.value!,
          engineVersion: engineVersion,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid room config payload: $error',
        ),
      );
    }
  }
}
