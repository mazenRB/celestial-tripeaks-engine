part of '../tripeaks_engine.dart';

/// Lightweight mutable wrapper around the pure session reducer.
///
/// This is convenient for app shells and quick prototypes while still keeping
/// deterministic core logic in immutable state reducers.
final class TriPeaksGame {
  /// Creates a new game session with [ruleset].
  ///
  /// To inject fixed decks for all rounds, pass [roundDecks]. Its length must
  /// match `ruleset.roundsPerGame`.
  TriPeaksGame.newGame({
    TriPeaksRuleset ruleset = TriPeaksRuleset.threeRounds,
    int? seed,
    List<List<Card>>? roundDecks,
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
    RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
    UndoConfig undoConfig = const UndoConfig(),
    StreakConfig streakConfig = const StreakConfig(),
    StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
    BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
  }) : _session = TriPeaksSessionState.newSession(
          ruleset: ruleset,
          seed: seed,
          roundDecks: roundDecks,
          scoreConfig: scoreConfig,
          roundRulesConfig: roundRulesConfig,
          roundTimerConfig: roundTimerConfig,
          undoConfig: undoConfig,
          streakConfig: streakConfig,
          strikeTimerConfig: strikeTimerConfig,
          bonusSlotsConfig: bonusSlotsConfig,
        );

  TriPeaksSessionState _session;

  /// Current immutable session state.
  TriPeaksSessionState get session => _session;

  /// Current immutable round state.
  TriPeaksState get state => _session.currentRound;

  /// Dispatches one action and stores the resulting state.
  void dispatch(TriPeaksSessionAction action) {
    _session = reduceTriPeaksSession(_session, action);
  }
}
