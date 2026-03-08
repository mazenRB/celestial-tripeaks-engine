part of '../tripeaks_engine.dart';

int dailySeedForDate(
  DateOnly date,
  DailyChallengeConfig config,
) {
  final payload = '${config.namespaceId}|${config.modeId}|'
      '${config.schemaVersion}|${date.toIsoString()}';
  return _fnv1a32(payload);
}

/// Creates a deterministic daily round from [date] and [config].
TriPeaksState newDailyGame(
  DateOnly date,
  DailyChallengeConfig config, {
  ScoreConfig scoreConfig = const ScoreConfig(),
  RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
  UndoConfig undoConfig = const UndoConfig(),
  StreakConfig streakConfig = const StreakConfig(),
  StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
  BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
}) {
  return TriPeaksState.newGame(
    seed: dailySeedForDate(date, config),
    scoreConfig: scoreConfig,
    roundRulesConfig: roundRulesConfig,
    undoConfig: undoConfig,
    streakConfig: streakConfig,
    strikeTimerConfig: strikeTimerConfig,
    bonusSlotsConfig: bonusSlotsConfig,
  );
}

/// Creates a deterministic daily round from a canonical engine preset.
TriPeaksState newDailyGameForPreset(
  DateOnly date, {
  required String namespaceId,
  required TriPeaksModePreset preset,
  int schemaVersion = 1,
}) {
  final config = DailyChallengeConfig.forPreset(
    namespaceId: namespaceId,
    preset: preset,
    schemaVersion: schemaVersion,
  );
  final bundle = TriPeaksModeBundle.forPreset(preset);
  return newDailyGame(
    date,
    config,
    scoreConfig: bundle.scoreConfig,
    roundRulesConfig: bundle.roundRulesConfig,
    undoConfig: bundle.undoConfig,
    streakConfig: bundle.streakConfig,
    strikeTimerConfig: bundle.strikeTimerConfig,
    bonusSlotsConfig: bundle.bonusSlotsConfig,
  );
}

/// Creates a deterministic daily session from [date] and [config].
TriPeaksSessionState newDailySession(
  DateOnly date,
  DailyChallengeConfig config, {
  ScoreConfig scoreConfig = const ScoreConfig(),
  RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
  UndoConfig undoConfig = const UndoConfig(),
  StreakConfig streakConfig = const StreakConfig(),
  StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
  BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
}) {
  final ruleset = _rulesetFromDailyConfig(config);
  return TriPeaksSessionState.newSession(
    ruleset: ruleset,
    seed: dailySeedForDate(date, config),
    scoreConfig: scoreConfig,
    roundRulesConfig: roundRulesConfig,
    undoConfig: undoConfig,
    streakConfig: streakConfig,
    strikeTimerConfig: strikeTimerConfig,
    bonusSlotsConfig: bonusSlotsConfig,
  );
}

/// Creates a deterministic daily session from a canonical engine preset.
TriPeaksSessionState newDailySessionForPreset(
  DateOnly date, {
  required String namespaceId,
  required TriPeaksModePreset preset,
  int schemaVersion = 1,
  int? roundCount,
}) {
  final bundle = TriPeaksModeBundle.forPreset(preset);
  final config = DailyChallengeConfig.forPreset(
    namespaceId: namespaceId,
    preset: preset,
    schemaVersion: schemaVersion,
    roundCount: roundCount ?? bundle.ruleset.roundsPerGame,
  );
  return newDailySession(
    date,
    config,
    scoreConfig: bundle.scoreConfig,
    roundRulesConfig: bundle.roundRulesConfig,
    undoConfig: bundle.undoConfig,
    streakConfig: bundle.streakConfig,
    strikeTimerConfig: bundle.strikeTimerConfig,
    bonusSlotsConfig: bundle.bonusSlotsConfig,
  );
}

TriPeaksRuleset _rulesetFromDailyConfig(DailyChallengeConfig config) {
  switch (config.roundCount) {
    case null:
    case 3:
      return TriPeaksRuleset.threeRounds;
    case 6:
      return TriPeaksRuleset.sixRounds;
    case 10:
      return TriPeaksRuleset.tenRounds;
    default:
      throw ArgumentError.value(
        config.roundCount,
        'roundCount',
        'Supported values are 3, 6, or 10.',
      );
  }
}

int _fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Returns all currently playable tableau indices for [state].
///
/// The same legality checks as gameplay are used, but evaluated against
/// [rulesConfig] for read-only hint/query use cases.
