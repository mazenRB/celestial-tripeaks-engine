import 'package:celestial_tripeaks/tripeaks_engine.dart';

/// Selects independent asynchronous matches or synchronized live rounds.
enum MatchMode { asynchronous, live }

/// Immutable rules and roster shared by every participant in a match.
final class MatchConfig {
  /// Creates a match configuration.
  const MatchConfig({
    required this.matchMode,
    required this.matchId,
    required this.matchSeed,
    required this.playerIds,
    this.ruleset = TriPeaksRuleset.threeRounds,
    this.scoreConfig = const ScoreConfig(),
    this.roundRulesConfig = const RoundRulesConfig(),
    this.roundTimerConfig = const RoundTimerConfig(),
    this.undoConfig = const UndoConfig(),
    this.streakConfig = const StreakConfig(),
    this.strikeTimerConfig = const StrikeTimerConfig(),
    this.bonusSlotsConfig = const BonusSlotsConfig(),
    this.dealPolicyConfig = const DealPolicyConfig(),
    this.asyncDeadlineSeconds = 604800,
    this.intermissionDurationSeconds = 15,
    this.skipVoteThreshold = 1,
  });

  /// Match lifecycle mode.
  final MatchMode matchMode;

  /// Stable identifier assigned by the integrating application.
  final String matchId;

  /// Shared deterministic seed used to generate each player's deals.
  final int matchSeed;

  /// Fixed participants. Live matches require at least two players.
  final List<String> playerIds;

  /// Number of rounds in each independently played match.
  final TriPeaksRuleset ruleset;

  /// Shared scoring policy.
  final ScoreConfig scoreConfig;

  /// Shared board rules.
  final RoundRulesConfig roundRulesConfig;

  /// Existing per-round timer schedule used by live matches.
  final RoundTimerConfig roundTimerConfig;

  /// Shared undo policy.
  final UndoConfig undoConfig;

  /// Shared streak policy.
  final StreakConfig streakConfig;

  /// Shared strike-timer policy.
  final StrikeTimerConfig strikeTimerConfig;

  /// Shared bonus-slot policy.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Shared deterministic deal-generation policy.
  final DealPolicyConfig dealPolicyConfig;

  /// Async match deadline in seconds; `null` disables it.
  final int? asyncDeadlineSeconds;

  /// Live intermission duration after all players finish a round.
  final int intermissionDurationSeconds;

  /// Fraction of the fixed roster required to vote for skipping.
  final double skipVoteThreshold;

  /// Returns a copy with selected settings replaced.
  MatchConfig copyWith({
    MatchMode? matchMode,
    String? matchId,
    int? matchSeed,
    List<String>? playerIds,
    TriPeaksRuleset? ruleset,
    ScoreConfig? scoreConfig,
    RoundRulesConfig? roundRulesConfig,
    RoundTimerConfig? roundTimerConfig,
    UndoConfig? undoConfig,
    StreakConfig? streakConfig,
    StrikeTimerConfig? strikeTimerConfig,
    BonusSlotsConfig? bonusSlotsConfig,
    DealPolicyConfig? dealPolicyConfig,
    int? asyncDeadlineSeconds,
    bool clearAsyncDeadline = false,
    int? intermissionDurationSeconds,
    double? skipVoteThreshold,
  }) {
    return MatchConfig(
      matchMode: matchMode ?? this.matchMode,
      matchId: matchId ?? this.matchId,
      matchSeed: matchSeed ?? this.matchSeed,
      playerIds: playerIds ?? this.playerIds,
      ruleset: ruleset ?? this.ruleset,
      scoreConfig: scoreConfig ?? this.scoreConfig,
      roundRulesConfig: roundRulesConfig ?? this.roundRulesConfig,
      roundTimerConfig: roundTimerConfig ?? this.roundTimerConfig,
      undoConfig: undoConfig ?? this.undoConfig,
      streakConfig: streakConfig ?? this.streakConfig,
      strikeTimerConfig: strikeTimerConfig ?? this.strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig ?? this.bonusSlotsConfig,
      dealPolicyConfig: dealPolicyConfig ?? this.dealPolicyConfig,
      asyncDeadlineSeconds: clearAsyncDeadline
          ? null
          : asyncDeadlineSeconds ?? this.asyncDeadlineSeconds,
      intermissionDurationSeconds:
          intermissionDurationSeconds ?? this.intermissionDurationSeconds,
      skipVoteThreshold: skipVoteThreshold ?? this.skipVoteThreshold,
    );
  }

  /// Serializes this configuration to a versioned map.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_match_config',
        'matchMode': matchMode.name,
        'matchId': matchId,
        'matchSeed': matchSeed,
        'playerIds': playerIds,
        'ruleset': ruleset.toMap(),
        'scoreConfig': scoreConfig.toMap(),
        'roundRulesConfig': roundRulesConfig.toMap(),
        'roundTimerConfig': roundTimerConfig.toMap(),
        'undoConfig': undoConfig.toMap(),
        'streakConfig': streakConfig.toMap(),
        'strikeTimerConfig': strikeTimerConfig.toMap(),
        'bonusSlotsConfig': bonusSlotsConfig.toMap(),
        'dealPolicyConfig': dealPolicyConfig.toMap(),
        'asyncDeadlineSeconds': asyncDeadlineSeconds,
        'intermissionDurationSeconds': intermissionDurationSeconds,
        'skipVoteThreshold': skipVoteThreshold,
      };

  /// Decodes a configuration map and reports malformed or unsupported data.
  static DecodeResult<MatchConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported multiplayer config schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_match_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown multiplayer config type.',
        ),
      );
    }
    try {
      final mode = MatchMode.values.byName(map['matchMode'] as String);
      final ids = (map['playerIds'] as List<dynamic>).cast<String>();
      final ruleset = TriPeaksRuleset.tryFromMap(
        _mapValue(map, 'ruleset'),
      );
      final score = ScoreConfig.tryFromMap(_mapValue(map, 'scoreConfig'));
      final roundRules = RoundRulesConfig.tryFromMap(
        _mapValue(map, 'roundRulesConfig'),
      );
      final roundTimer = RoundTimerConfig.tryFromMap(
        _mapValue(map, 'roundTimerConfig'),
      );
      final undo = UndoConfig.tryFromMap(_mapValue(map, 'undoConfig'));
      final streak = StreakConfig.tryFromMap(_mapValue(map, 'streakConfig'));
      final strike = StrikeTimerConfig.tryFromMap(
        _mapValue(map, 'strikeTimerConfig'),
      );
      final bonus = BonusSlotsConfig.tryFromMap(
        _mapValue(map, 'bonusSlotsConfig'),
      );
      final deal = DealPolicyConfig.tryFromMap(
        _mapValue(map, 'dealPolicyConfig'),
      );
      final deadline = map['asyncDeadlineSeconds'];
      final intermission = map['intermissionDurationSeconds'];
      final threshold = map['skipVoteThreshold'];
      final seed = map['matchSeed'];
      if (deadline != null && deadline is! int ||
          intermission is! int ||
          threshold is! num ||
          seed is! int) {
        throw const FormatException('Invalid match timing or seed.');
      }
      final results = <DecodeResult<Object>>[
        ruleset,
        score,
        roundRules,
        roundTimer,
        undo,
        streak,
        strike,
        bonus,
        deal,
      ];
      final failed = results.where((result) => !result.isSuccess).firstOrNull;
      if (failed != null) {
        return DecodeResult.failure(failed.error!);
      }
      return DecodeResult.success(
        MatchConfig(
          matchMode: mode,
          matchId: map['matchId'] as String,
          matchSeed: seed,
          playerIds: List<String>.unmodifiable(ids),
          ruleset: ruleset.value!,
          scoreConfig: score.value!,
          roundRulesConfig: roundRules.value!,
          roundTimerConfig: roundTimer.value!,
          undoConfig: undo.value!,
          streakConfig: streak.value!,
          strikeTimerConfig: strike.value!,
          bonusSlotsConfig: bonus.value!,
          dealPolicyConfig: deal.value!,
          asyncDeadlineSeconds: deadline as int?,
          intermissionDurationSeconds: intermission,
          skipVoteThreshold: threshold.toDouble(),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid multiplayer config: $error',
        ),
      );
    }
  }
}

Map<String, dynamic> _mapValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$key must be a map.');
}
