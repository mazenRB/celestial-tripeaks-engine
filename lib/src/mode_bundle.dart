part of '../tripeaks_engine.dart';

/// Resolved engine-owned gameplay preset bundle.
///
/// The [preset] field is stable metadata. Serialized bundles preserve the
/// nested resolved config values exactly as written and are not re-resolved
/// from the current preset catalog during decode.
final class TriPeaksModeBundle {
  /// Creates a fully resolved mode bundle.
  const TriPeaksModeBundle({
    required this.preset,
    required this.ruleset,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.roundTimerConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.dealPolicyConfig,
  });

  /// Canonical standard-solitaire preset.
  static const TriPeaksModeBundle classic = TriPeaksModeBundle(
    preset: TriPeaksModePreset.classic,
    ruleset: TriPeaksRuleset.oneRound,
    scoreConfig: ScoreConfig(
      pointsTableauToWaste: 4096,
      penaltyInvalidAction: -20000,
      pointsPeakCleared: 200000,
      pointsPerRemainingStockCardOnWin: 50000,
    ),
    roundRulesConfig: RoundRulesConfig(
      aceKingWrapAround: false,
      startStockSize: 23,
      stockDecreaseEveryRounds: 999999,
      minStockSize: 23,
    ),
    roundTimerConfig: RoundTimerConfig(),
    undoConfig: UndoConfig(enabled: false, maxSteps: 0),
    streakConfig: StreakConfig(),
    strikeTimerConfig: StrikeTimerConfig(enabled: false),
    bonusSlotsConfig: BonusSlotsConfig(enabled: false),
    dealPolicyConfig: DealPolicyConfig(),
  );

  // Centralized celestial tuning values. Adjust here when balancing changes.
  static final TriPeaksModeBundle celestial = TriPeaksModeBundle(
    preset: TriPeaksModePreset.celestial,
    ruleset: TriPeaksRuleset.tenRounds,
    scoreConfig: const ScoreConfig(
      pointsTableauToWaste: 4096,
      penaltyInvalidAction: -20000,
      allowNegativeTotalScore: false,
      pointsPeakCleared: 200000,
      pointsPerRemainingStockCardOnWin: 50000,
      multiplierMode: ScoreMultiplierMode.timeBonus,
      timeBonusSecondsPerMove: 2,
      timeBonusMaxSeconds: 10,
      roundBasePointsGrowthBps: 1000,
    ),
    roundRulesConfig: const RoundRulesConfig(
      startStockSize: 21,
      stockDecreaseEveryRounds: 2,
      minStockSize: 16,
    ),
    roundTimerConfig: const RoundTimerConfig(
      enabled: true,
      durationsSecondsByRound: <int>[
        88,
        81,
        76,
        70,
        65,
        61,
        56,
        52,
        49,
        45,
      ],
    ),
    undoConfig: const UndoConfig(enabled: false, maxSteps: 0),
    streakConfig: const StreakConfig(),
    strikeTimerConfig: const StrikeTimerConfig(enabled: false),
    bonusSlotsConfig: const BonusSlotsConfig(
      spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
      spawnOnOpenSlot2AtStreak: 3,
      spawnOnOpenSlot3AtStreak: 8,
      closeOnDraw: true,
      closeOnInvalidAction: true,
    ),
    dealPolicyConfig: const DealPolicyConfig(
      mode: DealPolicyMode.requireSolvable,
      maxAttempts: 200,
      attemptSeedStrategy: AttemptSeedStrategy.fnv1aMix,
      solverNodeLimit: 300000,
    ),
  );

  /// Returns the canonical bundle for [preset].
  static TriPeaksModeBundle forPreset(TriPeaksModePreset preset) {
    return switch (preset) {
      TriPeaksModePreset.classic => classic,
      TriPeaksModePreset.celestial => celestial,
    };
  }

  /// Stable preset metadata.
  final TriPeaksModePreset preset;

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

  /// Bonus slots config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Deal policy config.
  final DealPolicyConfig dealPolicyConfig;

  /// Serializes the bundle to a JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_mode_bundle',
      'presetId': preset.modeId,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'dealPolicyConfig': dealPolicyConfig.toMap(),
    };
  }

  /// Decodes a serialized resolved bundle without re-resolving preset values.
  static DecodeResult<TriPeaksModeBundle> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'tripeaks_mode_bundle') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final presetId = map['presetId'];
    final rulesetMap = map['ruleset'];
    final scoreConfigMap = map['scoreConfig'];
    final roundRulesConfigMap = map['roundRulesConfig'];
    final roundTimerConfigMap = map['roundTimerConfig'];
    final undoConfigMap = map['undoConfig'];
    final streakConfigMap = map['streakConfig'];
    final strikeTimerConfigMap = map['strikeTimerConfig'];
    final bonusSlotsConfigMap = map['bonusSlotsConfig'];
    final dealPolicyConfigMap = map['dealPolicyConfig'];
    if (presetId is! String ||
        rulesetMap is! Map<String, dynamic> ||
        scoreConfigMap is! Map<String, dynamic> ||
        roundRulesConfigMap is! Map<String, dynamic> ||
        (roundTimerConfigMap != null &&
            roundTimerConfigMap is! Map<String, dynamic>) ||
        undoConfigMap is! Map<String, dynamic> ||
        streakConfigMap is! Map<String, dynamic> ||
        strikeTimerConfigMap is! Map<String, dynamic> ||
        bonusSlotsConfigMap is! Map<String, dynamic> ||
        dealPolicyConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid TriPeaksModeBundle payload.',
        ),
      );
    }
    final preset = TriPeaksModePreset.tryParseModeId(presetId);
    if (preset == null) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Unknown presetId $presetId.',
        ),
      );
    }
    final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!rulesetResult.isSuccess) {
      return DecodeResult.failure(rulesetResult.error!);
    }
    final scoreConfigResult = ScoreConfig.tryFromMap(scoreConfigMap);
    if (!scoreConfigResult.isSuccess) {
      return DecodeResult.failure(scoreConfigResult.error!);
    }
    final roundRulesConfigResult =
        RoundRulesConfig.tryFromMap(roundRulesConfigMap);
    if (!roundRulesConfigResult.isSuccess) {
      return DecodeResult.failure(roundRulesConfigResult.error!);
    }
    DecodeResult<RoundTimerConfig>? roundTimerConfigResult;
    if (roundTimerConfigMap != null) {
      roundTimerConfigResult = RoundTimerConfig.tryFromMap(
        roundTimerConfigMap as Map<String, dynamic>,
      );
      if (!roundTimerConfigResult.isSuccess) {
        return DecodeResult.failure(roundTimerConfigResult.error!);
      }
    }
    final undoConfigResult = UndoConfig.tryFromMap(undoConfigMap);
    if (!undoConfigResult.isSuccess) {
      return DecodeResult.failure(undoConfigResult.error!);
    }
    final streakConfigResult = StreakConfig.tryFromMap(streakConfigMap);
    if (!streakConfigResult.isSuccess) {
      return DecodeResult.failure(streakConfigResult.error!);
    }
    final strikeTimerConfigResult =
        StrikeTimerConfig.tryFromMap(strikeTimerConfigMap);
    if (!strikeTimerConfigResult.isSuccess) {
      return DecodeResult.failure(strikeTimerConfigResult.error!);
    }
    final bonusSlotsConfigResult =
        BonusSlotsConfig.tryFromMap(bonusSlotsConfigMap);
    if (!bonusSlotsConfigResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfigResult.error!);
    }
    final dealPolicyConfigResult =
        DealPolicyConfig.tryFromMap(dealPolicyConfigMap);
    if (!dealPolicyConfigResult.isSuccess) {
      return DecodeResult.failure(dealPolicyConfigResult.error!);
    }
    return DecodeResult.success(
      TriPeaksModeBundle(
        preset: preset,
        ruleset: rulesetResult.value!,
        scoreConfig: scoreConfigResult.value!,
        roundRulesConfig: roundRulesConfigResult.value!,
        roundTimerConfig:
            roundTimerConfigResult?.value ?? const RoundTimerConfig(),
        undoConfig: undoConfigResult.value!,
        streakConfig: streakConfigResult.value!,
        strikeTimerConfig: strikeTimerConfigResult.value!,
        bonusSlotsConfig: bonusSlotsConfigResult.value!,
        dealPolicyConfig: dealPolicyConfigResult.value!,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TriPeaksModeBundle &&
        other.preset == preset &&
        _canonicalBundleMap(other.ruleset.toMap()) ==
            _canonicalBundleMap(ruleset.toMap()) &&
        _canonicalBundleMap(other.scoreConfig.toMap()) ==
            _canonicalBundleMap(scoreConfig.toMap()) &&
        _canonicalBundleMap(other.roundRulesConfig.toMap()) ==
            _canonicalBundleMap(roundRulesConfig.toMap()) &&
        _canonicalBundleMap(other.roundTimerConfig.toMap()) ==
            _canonicalBundleMap(roundTimerConfig.toMap()) &&
        _canonicalBundleMap(other.undoConfig.toMap()) ==
            _canonicalBundleMap(undoConfig.toMap()) &&
        _canonicalBundleMap(other.streakConfig.toMap()) ==
            _canonicalBundleMap(streakConfig.toMap()) &&
        _canonicalBundleMap(other.strikeTimerConfig.toMap()) ==
            _canonicalBundleMap(strikeTimerConfig.toMap()) &&
        _canonicalBundleMap(other.bonusSlotsConfig.toMap()) ==
            _canonicalBundleMap(bonusSlotsConfig.toMap()) &&
        _canonicalBundleMap(other.dealPolicyConfig.toMap()) ==
            _canonicalBundleMap(dealPolicyConfig.toMap());
  }

  @override
  int get hashCode => Object.hash(
        preset,
        _canonicalBundleMap(ruleset.toMap()),
        _canonicalBundleMap(scoreConfig.toMap()),
        _canonicalBundleMap(roundRulesConfig.toMap()),
        _canonicalBundleMap(roundTimerConfig.toMap()),
        _canonicalBundleMap(undoConfig.toMap()),
        _canonicalBundleMap(streakConfig.toMap()),
        _canonicalBundleMap(strikeTimerConfig.toMap()),
        _canonicalBundleMap(bonusSlotsConfig.toMap()),
        _canonicalBundleMap(dealPolicyConfig.toMap()),
      );
}

String _canonicalBundleMap(Map<String, dynamic> map) => jsonEncode(map);
