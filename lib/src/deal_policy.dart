part of '../tripeaks_engine.dart';

/// Deal generation mode.
enum DealPolicyMode {
  random,
  requireSolvable,
}

/// Deterministic seed derivation strategy for attempts.
enum AttemptSeedStrategy {
  baseSeedPlusAttempt,
  fnv1aMix,
}

/// Config for deterministic deal selection policy.
final class DealPolicyConfig {
  /// Creates a deal policy config.
  const DealPolicyConfig({
    this.mode = DealPolicyMode.random,
    this.maxAttempts = 200,
    this.attemptSeedStrategy = AttemptSeedStrategy.baseSeedPlusAttempt,
    this.solverNodeLimit = 300000,
  })  : assert(maxAttempts > 0),
        assert(solverNodeLimit > 0);

  /// Deal generation mode.
  final DealPolicyMode mode;

  /// Maximum attempts for selecting a deal.
  final int maxAttempts;

  /// Seed derivation strategy for each attempt.
  final AttemptSeedStrategy attemptSeedStrategy;

  /// Maximum solver nodes visited for one solvability check.
  final int solverNodeLimit;

  /// Serializes policy config to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'deal_policy_config',
      'mode': mode.name,
      'maxAttempts': maxAttempts,
      'attemptSeedStrategy': attemptSeedStrategy.name,
      'solverNodeLimit': solverNodeLimit,
    };
  }

  /// Decodes policy config from map without throwing.
  static DecodeResult<DealPolicyConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'deal_policy_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final mode = map['mode'];
    final maxAttempts = map['maxAttempts'];
    final attemptSeedStrategy = map['attemptSeedStrategy'];
    final solverNodeLimit = map['solverNodeLimit'];
    if (mode is! String ||
        maxAttempts is! int ||
        attemptSeedStrategy is! String ||
        solverNodeLimit is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid DealPolicyConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        DealPolicyConfig(
          mode: DealPolicyMode.values.byName(mode),
          maxAttempts: maxAttempts,
          attemptSeedStrategy:
              AttemptSeedStrategy.values.byName(attemptSeedStrategy),
          solverNodeLimit: solverNodeLimit,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid DealPolicyConfig payload: $error',
        ),
      );
    }
  }
}

/// Deal generation failure code.
enum DealFailureCode {
  noSolvableDealFound,
}

/// Typed deal generation failure.
final class DealFailure {
  /// Creates deal failure details.
  const DealFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly failure code.
  final DealFailureCode code;

  /// Human-friendly failure message.
  final String message;
}

/// Result for deal generation.
final class DealGenerationResult {
  /// Creates deal generation result.
  const DealGenerationResult({
    this.state,
    this.attemptSeed,
    this.attemptCount,
    this.failure,
  });

  /// Chosen game state when successful.
  final TriPeaksState? state;

  /// Seed used for selected deal when successful.
  final int? attemptSeed;

  /// Number of attempts consumed.
  final int? attemptCount;

  /// Failure details for unsuccessful generation.
  final DealFailure? failure;

  /// Whether generation succeeded.
  bool get isSuccess => failure == null;
}

/// Creates a new game using deterministic [dealPolicy].
DealGenerationResult newGameWithDealPolicy(
  int baseSeed, {
  ScoreConfig scoreConfig = const ScoreConfig(),
  RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
  RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
  UndoConfig undoConfig = const UndoConfig(),
  StreakConfig streakConfig = const StreakConfig(),
  StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
  BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
  DealPolicyConfig dealPolicy = const DealPolicyConfig(),
}) {
  switch (dealPolicy.mode) {
    case DealPolicyMode.random:
      final state = TriPeaksState.newGame(
        seed: baseSeed,
        scoreConfig: scoreConfig,
        roundRulesConfig: roundRulesConfig,
        roundTimerConfig: roundTimerConfig,
        undoConfig: undoConfig,
        streakConfig: streakConfig,
        strikeTimerConfig: strikeTimerConfig,
        bonusSlotsConfig: bonusSlotsConfig,
      );
      return DealGenerationResult(
        state: state,
        attemptSeed: baseSeed,
        attemptCount: 1,
      );

    case DealPolicyMode.requireSolvable:
      for (var attempt = 0; attempt < dealPolicy.maxAttempts; attempt++) {
        final seed = _dealAttemptSeed(
          baseSeed: baseSeed,
          attemptIndex: attempt,
          strategy: dealPolicy.attemptSeedStrategy,
        );
        final state = TriPeaksState.newGame(
          seed: seed,
          scoreConfig: scoreConfig,
          roundRulesConfig: roundRulesConfig,
          roundTimerConfig: roundTimerConfig,
          undoConfig: undoConfig,
          streakConfig: streakConfig,
          strikeTimerConfig: strikeTimerConfig,
          bonusSlotsConfig: bonusSlotsConfig,
        );
        if (isDealSolvable(
          state,
          nodeLimit: dealPolicy.solverNodeLimit,
        )) {
          return DealGenerationResult(
            state: state,
            attemptSeed: seed,
            attemptCount: attempt + 1,
          );
        }
      }

      return const DealGenerationResult(
        failure: DealFailure(
          code: DealFailureCode.noSolvableDealFound,
          message: 'No solvable deal found within maxAttempts.',
        ),
      );
  }
}

/// Creates a daily game using deterministic [dealPolicy].
DealGenerationResult newDailyGameWithDealPolicy(
  DateOnly date,
  DailyChallengeConfig dailyConfig, {
  ScoreConfig scoreConfig = const ScoreConfig(),
  RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
  RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
  UndoConfig undoConfig = const UndoConfig(),
  StreakConfig streakConfig = const StreakConfig(),
  StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
  BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
  DealPolicyConfig dealPolicy = const DealPolicyConfig(),
}) {
  final baseSeed = dailySeedForDate(date, dailyConfig);
  return newGameWithDealPolicy(
    baseSeed,
    scoreConfig: scoreConfig,
    roundRulesConfig: roundRulesConfig,
    roundTimerConfig: roundTimerConfig,
    undoConfig: undoConfig,
    streakConfig: streakConfig,
    strikeTimerConfig: strikeTimerConfig,
    bonusSlotsConfig: bonusSlotsConfig,
    dealPolicy: dealPolicy,
  );
}

/// Returns whether [state] is solvable under current rules.
///
/// The solver is deterministic and bounded by [nodeLimit].
bool isDealSolvable(
  TriPeaksState state, {
  int nodeLimit = 300000,
}) {
  final solver = _SolvabilitySolver(
    state: state,
    nodeLimit: nodeLimit,
  );
  return solver.solve();
}

int _dealAttemptSeed({
  required int baseSeed,
  required int attemptIndex,
  required AttemptSeedStrategy strategy,
}) {
  switch (strategy) {
    case AttemptSeedStrategy.baseSeedPlusAttempt:
      return (baseSeed + attemptIndex) & 0x7FFFFFFF;
    case AttemptSeedStrategy.fnv1aMix:
      return _fnv1a32('$baseSeed|$attemptIndex');
  }
}
