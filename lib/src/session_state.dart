part of 'tripeaks_engine_internal.dart';

/// Compact derived status helper for common session UX.
///
/// This is a convenience view over existing session and round facts, not a
/// separate source of truth.
enum TriPeaksSessionStatus {
  inProgress,
  won,
  lost,
  timedOut,
  gameOver,
}

/// Immutable multi-round TriPeaks session state snapshot.
///
/// This wraps one active round plus completed round history and aggregate
/// counters such as wins/losses/aborts.
final class TriPeaksSessionState {
  /// Default deterministic session seed used when no explicit seed is provided.
  static const int defaultSeed = 0;

  /// Creates a new session.
  ///
  /// When [roundDecks] is provided, its length must equal
  /// [ruleset.roundsPerGame] and each deck must be valid.
  factory TriPeaksSessionState.newSession({
    required TriPeaksRuleset ruleset,
    int? seed,
    List<List<Card>>? roundDecks,
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
    RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
    UndoConfig undoConfig = const UndoConfig(),
    StreakConfig streakConfig = const StreakConfig(),
    StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
    BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
  }) {
    if (roundDecks != null && roundDecks.length != ruleset.roundsPerGame) {
      throw ArgumentError.value(
        roundDecks.length,
        'roundDecks.length',
        'Must match roundsPerGame (${ruleset.roundsPerGame}).',
      );
    }
    if (roundDecks case final decks?) {
      for (final deck in decks) {
        TriPeaksState.newGame(deck: deck);
      }
    }
    if (_roundTimerConfigValidationMessage(
      roundTimerConfig,
      ruleset.roundsPerGame,
    )
        case final timerError?) {
      throw ArgumentError.value(
        roundTimerConfig.durationsSecondsByRound,
        'roundTimerConfig',
        timerError,
      );
    }

    final effectiveSeed = seed ?? defaultSeed;

    final firstRound = _buildRoundState(
      roundNumber: 1,
      seed: effectiveSeed,
      roundDecks: roundDecks,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
    );

    return TriPeaksSessionState._(
      ruleset: ruleset,
      seed: effectiveSeed,
      roundDecks: roundDecks,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      currentRoundNumber: 1,
      roundsCompleted: 0,
      roundsWon: 0,
      roundsLost: 0,
      roundsTimedOut: 0,
      roundsAborted: 0,
      roundResults: const <RoundResult>[],
      currentRound: firstRound,
    );
  }

  const TriPeaksSessionState._({
    required this.ruleset,
    required this.seed,
    required this.roundDecks,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.roundTimerConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.currentRoundNumber,
    required this.roundsCompleted,
    required this.roundsWon,
    required this.roundsLost,
    required this.roundsTimedOut,
    required this.roundsAborted,
    required this.roundResults,
    required this.currentRound,
  });

  /// Active ruleset for this session.
  final TriPeaksRuleset ruleset;

  final int? seed;
  final List<List<Card>>? roundDecks;
  final ScoreConfig scoreConfig;
  final RoundRulesConfig roundRulesConfig;
  final RoundTimerConfig roundTimerConfig;
  final UndoConfig undoConfig;
  final StreakConfig streakConfig;
  final StrikeTimerConfig strikeTimerConfig;
  final BonusSlotsConfig bonusSlotsConfig;

  /// Current 1-based round number.
  final int currentRoundNumber;

  /// Number of rounds already completed.
  final int roundsCompleted;

  /// Number of rounds won.
  final int roundsWon;

  /// Number of rounds lost.
  final int roundsLost;

  /// Number of rounds timed out.
  final int roundsTimedOut;

  /// Number of rounds aborted.
  final int roundsAborted;

  /// Completed round results in chronological order.
  final List<RoundResult> roundResults;

  /// Current round state.
  final TriPeaksState currentRound;

  /// Number of rounds remaining after this point.
  int get roundsRemaining => ruleset.roundsPerGame - roundsCompleted;

  /// Whether the current round has ended.
  bool get isCurrentRoundFinished => currentRound.isFinished;

  /// Whether all rounds in the session have been completed.
  bool get isSessionFinished => roundsCompleted >= ruleset.roundsPerGame;

  /// Sum of known scores from completed rounds.
  ///
  /// Legacy decoded [RoundResult] entries without [RoundResult.finalScore] are
  /// skipped deterministically.
  int get cumulativeFinishedRoundsScoreTotal {
    var total = 0;
    for (final result in roundResults) {
      total += result.finalScore ?? 0;
    }
    return total;
  }

  /// Cumulative score including the current in-progress round only.
  ///
  /// This avoids double-counting after round completion because finished rounds
  /// are already represented in [roundResults].
  int get cumulativeIncludingCurrentRoundScoreTotal {
    if (isCurrentRoundFinished) {
      return cumulativeFinishedRoundsScoreTotal;
    }
    return cumulativeFinishedRoundsScoreTotal +
        currentRound.scoreState.totalScore;
  }

  /// Derived deterministic status for common UI and integration helpers.
  TriPeaksSessionStatus get status {
    if (isSessionFinished) {
      return TriPeaksSessionStatus.gameOver;
    }
    if (currentRound.isWon) {
      return TriPeaksSessionStatus.won;
    }
    if (currentRound.isLost) {
      return TriPeaksSessionStatus.lost;
    }
    if (currentRound.isTimedOut) {
      return TriPeaksSessionStatus.timedOut;
    }
    return TriPeaksSessionStatus.inProgress;
  }

  bool get _hasNextRound => currentRoundNumber < ruleset.roundsPerGame;

  TriPeaksSessionState _copyWith({
    int? currentRoundNumber,
    int? roundsCompleted,
    int? roundsWon,
    int? roundsLost,
    int? roundsTimedOut,
    int? roundsAborted,
    List<RoundResult>? roundResults,
    TriPeaksState? currentRound,
  }) {
    return TriPeaksSessionState._(
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
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      roundsWon: roundsWon ?? this.roundsWon,
      roundsLost: roundsLost ?? this.roundsLost,
      roundsTimedOut: roundsTimedOut ?? this.roundsTimedOut,
      roundsAborted: roundsAborted ?? this.roundsAborted,
      roundResults: List<RoundResult>.unmodifiable(
        roundResults ?? this.roundResults,
      ),
      currentRound: currentRound ?? this.currentRound,
    );
  }

  static TriPeaksState _buildRoundState({
    required int roundNumber,
    required int? seed,
    required List<List<Card>>? roundDecks,
    required ScoreConfig scoreConfig,
    required RoundRulesConfig roundRulesConfig,
    required RoundTimerConfig roundTimerConfig,
    required UndoConfig undoConfig,
    required StreakConfig streakConfig,
    required StrikeTimerConfig strikeTimerConfig,
    required BonusSlotsConfig bonusSlotsConfig,
  }) {
    if (roundDecks case final decks?) {
      return TriPeaksState.newGame(
        deck: decks[roundNumber - 1],
        roundNumber: roundNumber,
        scoreConfig: scoreConfig,
        roundRulesConfig: roundRulesConfig,
        roundTimerConfig: roundTimerConfig,
        undoConfig: undoConfig,
        streakConfig: streakConfig,
        strikeTimerConfig: strikeTimerConfig,
        bonusSlotsConfig: bonusSlotsConfig,
      );
    }

    final roundSeed = seed == null ? null : seed + roundNumber - 1;
    return TriPeaksState.newGame(
      seed: roundSeed,
      roundNumber: roundNumber,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
    );
  }

  /// Serializes session state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_session_state',
      'ruleset': ruleset.toMap(),
      if (seed case final value?) 'seed': value,
      if (roundDecks case final decks?)
        'roundDecks': decks
            .map(
              (deck) =>
                  deck.map((card) => card.toMap()).toList(growable: false),
            )
            .toList(growable: false),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'currentRoundNumber': currentRoundNumber,
      'roundsCompleted': roundsCompleted,
      'roundsWon': roundsWon,
      'roundsLost': roundsLost,
      'roundsTimedOut': roundsTimedOut,
      'roundsAborted': roundsAborted,
      'roundResults': roundResults.map((value) => value.toMap()).toList(
            growable: false,
          ),
      'currentRound': currentRound.toMap(),
    };
  }

  /// Decodes session state from map without throwing.
  static DecodeResult<TriPeaksSessionState> tryFromMap(
    Map<String, dynamic> map,
  ) {
    return _decodeTriPeaksSessionState(map);
  }
}

/// Derives deterministic daily seed from [date] and [config].
///
/// The algorithm is platform-independent and does not use Dart `hashCode`.
