part of 'tripeaks_engine_internal.dart';

/// Session replay payload for deterministic reconstruction.
final class ReplaySession {
  /// Supported replay schema version.
  static const int supportedSchemaVersion = 1;

  /// Creates a replay payload.
  const ReplaySession({
    required this.schemaVersion,
    required this.engineVersion,
    required this.seed,
    required this.ruleset,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.roundTimerConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.entries,
  });

  /// Creates an empty replay log for a deterministic session.
  factory ReplaySession.newSession({
    required int seed,
    TriPeaksRuleset ruleset = TriPeaksRuleset.threeRounds,
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
    RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
    UndoConfig undoConfig = const UndoConfig(),
    StreakConfig streakConfig = const StreakConfig(),
    StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
    BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
    int schemaVersion = supportedSchemaVersion,
    int engineVersion = 1,
  }) {
    return ReplaySession(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      seed: seed,
      ruleset: ruleset,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      entries: const <ReplayEntry>[],
    );
  }

  /// Replay schema version.
  final int schemaVersion;

  /// Engine version used to produce this replay.
  final int engineVersion;

  /// Initial deterministic seed.
  final int seed;

  /// Session ruleset.
  final TriPeaksRuleset ruleset;

  /// Score config.
  final ScoreConfig scoreConfig;

  /// Round rules config.
  final RoundRulesConfig roundRulesConfig;

  /// Round timer config.
  final RoundTimerConfig roundTimerConfig;

  /// Undo config.
  final UndoConfig undoConfig;

  /// Streak config.
  final StreakConfig streakConfig;

  /// Strike timer config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Bonus-slots config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Ordered append-only attempts log.
  final List<ReplayEntry> entries;

  /// Serializes replay to a JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'replay_session',
      'engineVersion': engineVersion,
      'seed': seed,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'entries': entries.map((entry) => entry.toMap()).toList(growable: false),
    };
  }

  /// Parses replay from [map] without throwing.
  static DecodeResult<ReplaySession> tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'schemaVersion must be an int.',
        ),
      );
    }
    if (schemaVersion != supportedSchemaVersion) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion $schemaVersion.',
        ),
      );
    }
    if (map['type'] != 'replay_session') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final rulesetMap = map['ruleset'];
    if (rulesetMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'ruleset must be a map.',
        ),
      );
    }
    final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!rulesetResult.isSuccess) {
      return DecodeResult.failure(rulesetResult.error!);
    }
    final scoreConfigMap = map['scoreConfig'];
    if (scoreConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'scoreConfig must be a map.',
        ),
      );
    }
    final scoreConfigResult = ScoreConfig.tryFromMap(scoreConfigMap);
    if (!scoreConfigResult.isSuccess) {
      return DecodeResult.failure(scoreConfigResult.error!);
    }
    final roundRulesMap = map['roundRulesConfig'];
    if (roundRulesMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundRulesConfig must be a map.',
        ),
      );
    }
    final roundRulesResult = RoundRulesConfig.tryFromMap(roundRulesMap);
    if (!roundRulesResult.isSuccess) {
      return DecodeResult.failure(roundRulesResult.error!);
    }
    final roundTimerMap = map['roundTimerConfig'];
    DecodeResult<RoundTimerConfig>? roundTimerResult;
    if (roundTimerMap != null) {
      if (roundTimerMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'roundTimerConfig must be a map when present.',
          ),
        );
      }
      roundTimerResult = RoundTimerConfig.tryFromMap(roundTimerMap);
      if (!roundTimerResult.isSuccess) {
        return DecodeResult.failure(roundTimerResult.error!);
      }
    }
    final undoConfigMap = map['undoConfig'];
    if (undoConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'undoConfig must be a map.',
        ),
      );
    }
    final undoConfigResult = UndoConfig.tryFromMap(undoConfigMap);
    if (!undoConfigResult.isSuccess) {
      return DecodeResult.failure(undoConfigResult.error!);
    }
    final streakConfigMap = map['streakConfig'];
    if (streakConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'streakConfig must be a map.',
        ),
      );
    }
    final streakConfigResult = StreakConfig.tryFromMap(streakConfigMap);
    if (!streakConfigResult.isSuccess) {
      return DecodeResult.failure(streakConfigResult.error!);
    }
    final strikeTimerConfigMap = map['strikeTimerConfig'];
    if (strikeTimerConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'strikeTimerConfig must be a map.',
        ),
      );
    }
    final strikeTimerConfigResult = StrikeTimerConfig.tryFromMap(
      strikeTimerConfigMap,
    );
    if (!strikeTimerConfigResult.isSuccess) {
      return DecodeResult.failure(strikeTimerConfigResult.error!);
    }
    final bonusSlotsConfigMap = map['bonusSlotsConfig'];
    if (bonusSlotsConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'bonusSlotsConfig must be a map.',
        ),
      );
    }
    final bonusSlotsConfigResult =
        BonusSlotsConfig.tryFromMap(bonusSlotsConfigMap);
    if (!bonusSlotsConfigResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfigResult.error!);
    }

    final entriesRaw = map['entries'];
    if (entriesRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'entries must be a list.',
        ),
      );
    }
    final entries = <ReplayEntry>[];
    for (final raw in entriesRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'entries must contain map items.',
          ),
        );
      }
      final entryResult = ReplayEntry.tryFromMap(raw);
      if (!entryResult.isSuccess) {
        return DecodeResult.failure(entryResult.error!);
      }
      entries.add(entryResult.value!);
    }

    final engineVersion = map['engineVersion'];
    final seed = map['seed'];
    if (engineVersion is! int || seed is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'engineVersion and seed must be ints.',
        ),
      );
    }

    return DecodeResult.success(
      ReplaySession(
        schemaVersion: schemaVersion,
        engineVersion: engineVersion,
        seed: seed,
        ruleset: rulesetResult.value!,
        scoreConfig: scoreConfigResult.value!,
        roundRulesConfig: roundRulesResult.value!,
        roundTimerConfig: roundTimerResult?.value ?? const RoundTimerConfig(),
        undoConfig: undoConfigResult.value!,
        streakConfig: streakConfigResult.value!,
        strikeTimerConfig: strikeTimerConfigResult.value!,
        bonusSlotsConfig: bonusSlotsConfigResult.value!,
        entries: List<ReplayEntry>.unmodifiable(entries),
      ),
    );
  }

  ReplaySession _copyWith({
    List<ReplayEntry>? entries,
  }) {
    return ReplaySession(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      seed: seed,
      ruleset: ruleset,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      entries: List<ReplayEntry>.unmodifiable(entries ?? this.entries),
    );
  }
}

/// Backwards-compatible alias.
typedef TriPeaksReplay = ReplaySession;
