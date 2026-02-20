part of '../tripeaks_engine.dart';

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

    final effectiveSeed = seed ?? defaultSeed;

    final firstRound = _buildRoundState(
      roundNumber: 1,
      seed: effectiveSeed,
      roundDecks: roundDecks,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
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
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      currentRoundNumber: 1,
      roundsCompleted: 0,
      roundsWon: 0,
      roundsLost: 0,
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
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.currentRoundNumber,
    required this.roundsCompleted,
    required this.roundsWon,
    required this.roundsLost,
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

  /// Number of rounds aborted.
  final int roundsAborted;

  /// Completed round results in chronological order.
  final List<RoundResult> roundResults;

  /// Current round state.
  final TriPeaksState currentRound;

  /// Number of rounds remaining after this point.
  int get roundsRemaining => ruleset.roundsPerGame - roundsCompleted;

  /// Whether the current round has ended.
  bool get isCurrentRoundFinished => currentRound.isWon || currentRound.isLost;

  /// Whether all rounds in the session have been completed.
  bool get isSessionFinished => roundsCompleted >= ruleset.roundsPerGame;

  bool get _hasNextRound => currentRoundNumber < ruleset.roundsPerGame;

  TriPeaksSessionState _copyWith({
    int? currentRoundNumber,
    int? roundsCompleted,
    int? roundsWon,
    int? roundsLost,
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
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      roundsWon: roundsWon ?? this.roundsWon,
      roundsLost: roundsLost ?? this.roundsLost,
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
    required UndoConfig undoConfig,
    required StreakConfig streakConfig,
    required StrikeTimerConfig strikeTimerConfig,
    required BonusSlotsConfig bonusSlotsConfig,
  }) {
    if (roundDecks case final decks?) {
      return TriPeaksState.newGame(
        deck: decks[roundNumber - 1],
        scoreConfig: scoreConfig,
        roundRulesConfig: roundRulesConfig,
        undoConfig: undoConfig,
        streakConfig: streakConfig,
        strikeTimerConfig: strikeTimerConfig,
        bonusSlotsConfig: bonusSlotsConfig,
      );
    }

    final roundSeed = seed == null ? null : seed + roundNumber - 1;
    return TriPeaksState.newGame(
      seed: roundSeed,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
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
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'currentRoundNumber': currentRoundNumber,
      'roundsCompleted': roundsCompleted,
      'roundsWon': roundsWon,
      'roundsLost': roundsLost,
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
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'tripeaks_session_state') {
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
    final currentRoundMap = map['currentRound'];
    if (currentRoundMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'currentRound must be a map.',
        ),
      );
    }
    final currentRoundResult = TriPeaksState.tryFromMap(currentRoundMap);
    if (!currentRoundResult.isSuccess) {
      return DecodeResult.failure(currentRoundResult.error!);
    }

    final roundResultsRaw = map['roundResults'];
    if (roundResultsRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundResults must be a list.',
        ),
      );
    }
    final roundResults = <RoundResult>[];
    for (final raw in roundResultsRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'roundResults items must be maps.',
          ),
        );
      }
      final decoded = RoundResult.tryFromMap(raw);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      roundResults.add(decoded.value!);
    }

    final roundDecksRaw = map['roundDecks'];
    List<List<Card>>? roundDecks;
    if (roundDecksRaw != null) {
      if (roundDecksRaw is! List<dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'roundDecks must be a list when present.',
          ),
        );
      }
      roundDecks = <List<Card>>[];
      for (final rawDeck in roundDecksRaw) {
        final decodedDeck = TriPeaksState._decodeCardList(rawDeck, 'roundDeck');
        if (!decodedDeck.isSuccess) {
          return DecodeResult.failure(decodedDeck.error!);
        }
        roundDecks.add(decodedDeck.value!);
      }
    }

    final seedRaw = map['seed'];
    if (seedRaw != null && seedRaw is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'seed must be int when present.',
        ),
      );
    }

    final currentRoundNumber = map['currentRoundNumber'];
    final roundsCompleted = map['roundsCompleted'];
    final roundsWon = map['roundsWon'];
    final roundsLost = map['roundsLost'];
    final roundsAborted = map['roundsAborted'];
    if (currentRoundNumber is! int ||
        roundsCompleted is! int ||
        roundsWon is! int ||
        roundsLost is! int ||
        roundsAborted is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid session numeric payload.',
        ),
      );
    }

    return DecodeResult.success(
      TriPeaksSessionState._(
        ruleset: rulesetResult.value!,
        seed: seedRaw as int?,
        roundDecks: roundDecks == null
            ? null
            : List<List<Card>>.unmodifiable(
                roundDecks.map(List<Card>.unmodifiable),
              ),
        scoreConfig: scoreConfigResult.value!,
        roundRulesConfig: roundRulesResult.value!,
        undoConfig: undoConfigResult.value!,
        streakConfig: streakConfigResult.value!,
        strikeTimerConfig: strikeTimerConfigResult.value!,
        bonusSlotsConfig: bonusSlotsConfigResult.value!,
        currentRoundNumber: currentRoundNumber,
        roundsCompleted: roundsCompleted,
        roundsWon: roundsWon,
        roundsLost: roundsLost,
        roundsAborted: roundsAborted,
        roundResults: List<RoundResult>.unmodifiable(roundResults),
        currentRound: currentRoundResult.value!,
      ),
    );
  }
}

/// Derives deterministic daily seed from [date] and [config].
///
/// The algorithm is platform-independent and does not use Dart `hashCode`.
