part of '../tripeaks_engine.dart';

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
