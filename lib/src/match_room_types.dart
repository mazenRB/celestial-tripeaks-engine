part of '../tripeaks_engine.dart';

/// Multiplayer match mode.
enum MatchMode {
  realtime,
  async,
}

/// Match lifecycle status.
enum MatchStatus {
  waiting,
  active,
  finished,
}

/// Per-player lifecycle status.
enum PlayerStatus {
  joined,
  active,
  finished,
  left,
}

/// Deterministic multiplayer match configuration.
final class MatchConfig {
  /// Creates a match config.
  const MatchConfig({
    required this.matchMode,
    required this.matchId,
    required this.matchSeed,
    required this.maxPlayers,
    this.ruleset = TriPeaksRuleset.threeRounds,
    this.scoreConfig = const ScoreConfig(),
    this.roundRulesConfig = const RoundRulesConfig(),
    this.undoConfig = const UndoConfig(),
    this.streakConfig = const StreakConfig(),
    this.strikeTimerConfig = const StrikeTimerConfig(),
    this.bonusSlotsConfig = const BonusSlotsConfig(),
    this.dealPolicyConfig = const DealPolicyConfig(),
    this.engineVersion = 1,
  }) : assert(maxPlayers > 0);

  /// Match mode.
  final MatchMode matchMode;

  /// Stable match identifier.
  final String matchId;

  /// Shared match seed for fair equivalent deals.
  final int matchSeed;

  /// Maximum number of players.
  final int maxPlayers;

  /// Shared session ruleset.
  final TriPeaksRuleset ruleset;

  /// Shared score config.
  final ScoreConfig scoreConfig;

  /// Shared round mechanics config.
  final RoundRulesConfig roundRulesConfig;

  /// Shared undo config.
  final UndoConfig undoConfig;

  /// Shared streak config.
  final StreakConfig streakConfig;

  /// Shared strike timer config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Shared bonus-slots config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Shared deal policy config.
  final DealPolicyConfig dealPolicyConfig;

  /// Engine version metadata.
  final int engineVersion;

  /// Serializes config to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_config',
      'matchMode': matchMode.name,
      'matchId': matchId,
      'matchSeed': matchSeed,
      'maxPlayers': maxPlayers,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'dealPolicyConfig': dealPolicyConfig.toMap(),
      'engineVersion': engineVersion,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<MatchConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final rulesetMap = map['ruleset'];
    final scoreMap = map['scoreConfig'];
    final roundRulesMap = map['roundRulesConfig'];
    final undoMap = map['undoConfig'];
    final streakMap = map['streakConfig'];
    final strikeTimerMap = map['strikeTimerConfig'];
    final bonusSlotsMap = map['bonusSlotsConfig'];
    final dealPolicyMap = map['dealPolicyConfig'];
    if (rulesetMap is! Map<String, dynamic> ||
        scoreMap is! Map<String, dynamic> ||
        roundRulesMap is! Map<String, dynamic> ||
        undoMap is! Map<String, dynamic> ||
        streakMap is! Map<String, dynamic> ||
        strikeTimerMap is! Map<String, dynamic> ||
        bonusSlotsMap is! Map<String, dynamic> ||
        dealPolicyMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid nested match config payload.',
        ),
      );
    }

    final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!rulesetResult.isSuccess) {
      return DecodeResult.failure(rulesetResult.error!);
    }
    final scoreResult = ScoreConfig.tryFromMap(scoreMap);
    if (!scoreResult.isSuccess) {
      return DecodeResult.failure(scoreResult.error!);
    }
    final roundRulesResult = RoundRulesConfig.tryFromMap(roundRulesMap);
    if (!roundRulesResult.isSuccess) {
      return DecodeResult.failure(roundRulesResult.error!);
    }
    final undoResult = UndoConfig.tryFromMap(undoMap);
    if (!undoResult.isSuccess) {
      return DecodeResult.failure(undoResult.error!);
    }
    final streakResult = StreakConfig.tryFromMap(streakMap);
    if (!streakResult.isSuccess) {
      return DecodeResult.failure(streakResult.error!);
    }
    final strikeTimerResult = StrikeTimerConfig.tryFromMap(strikeTimerMap);
    if (!strikeTimerResult.isSuccess) {
      return DecodeResult.failure(strikeTimerResult.error!);
    }
    final bonusSlotsResult = BonusSlotsConfig.tryFromMap(bonusSlotsMap);
    if (!bonusSlotsResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsResult.error!);
    }
    final dealPolicyResult = DealPolicyConfig.tryFromMap(dealPolicyMap);
    if (!dealPolicyResult.isSuccess) {
      return DecodeResult.failure(dealPolicyResult.error!);
    }

    final modeName = map['matchMode'];
    final matchId = map['matchId'];
    final matchSeed = map['matchSeed'];
    final maxPlayers = map['maxPlayers'];
    final engineVersion = map['engineVersion'];
    if (modeName is! String ||
        matchId is! String ||
        matchSeed is! int ||
        maxPlayers is! int ||
        engineVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid primitive match config fields.',
        ),
      );
    }

    try {
      return DecodeResult.success(
        MatchConfig(
          matchMode: MatchMode.values.byName(modeName),
          matchId: matchId,
          matchSeed: matchSeed,
          maxPlayers: maxPlayers,
          ruleset: rulesetResult.value!,
          scoreConfig: scoreResult.value!,
          roundRulesConfig: roundRulesResult.value!,
          undoConfig: undoResult.value!,
          streakConfig: streakResult.value!,
          strikeTimerConfig: strikeTimerResult.value!,
          bonusSlotsConfig: bonusSlotsResult.value!,
          dealPolicyConfig: dealPolicyResult.value!,
          engineVersion: engineVersion,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match config payload: $error',
        ),
      );
    }
  }
}
