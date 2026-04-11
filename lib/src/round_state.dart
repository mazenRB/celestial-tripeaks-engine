part of 'tripeaks_engine_internal.dart';

/// Immutable single-round TriPeaks state snapshot.
///
/// All reducers return new instances of this state to keep transitions
/// deterministic and replay-safe.
final class TriPeaksState {
  /// Default deterministic seed used when no explicit seed is provided.
  static const int defaultSeed = 0;

  /// Creates a new state from a shuffled or custom [deck].
  ///
  /// When [deck] is omitted, a shuffled standard deck is generated with
  /// deterministic seed behavior. If [seed] is omitted, [defaultSeed] is used.
  factory TriPeaksState.newGame({
    int? seed,
    List<Card>? deck,
    int roundNumber = 1,
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
    RoundTimerConfig roundTimerConfig = const RoundTimerConfig(),
    UndoConfig undoConfig = const UndoConfig(),
    StreakConfig streakConfig = const StreakConfig(),
    StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
    BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
  }) {
    final effectiveSeed = seed ?? defaultSeed;
    final workingDeck = deck == null
        ? (Card.standardDeck()..shuffle(Random(effectiveSeed)))
        : List<Card>.from(deck);
    _validateDeck(workingDeck);
    final tableauCardsNeeded = _tableauSize;
    const wasteCardsNeeded = 1;
    final stockSize = _computeStockSize(
      roundNumber,
      roundRulesConfig,
    );
    final available =
        workingDeck.length - tableauCardsNeeded - wasteCardsNeeded;
    if (stockSize > available) {
      throw ArgumentError.value(
        stockSize,
        'stockSize',
        'Stock size exceeds available cards ($available).',
      );
    }
    final initialWaste = workingDeck[tableauCardsNeeded];
    final initialBonusSlots = BonusSlotsState.initial.copyWith(
      slots: <List<Card>>[
        <Card>[initialWaste],
        <Card>[],
        <Card>[],
      ],
    );

    return TriPeaksState._(
      tableau: workingDeck.take(tableauCardsNeeded).toList(growable: false),
      removed: List<bool>.filled(tableauCardsNeeded, false, growable: false),
      waste: <Card>[initialWaste],
      stock: workingDeck
          .skip(tableauCardsNeeded + wasteCardsNeeded)
          .take(stockSize)
          .toList(growable: false),
      roundNumber: roundNumber,
      roundSeed: effectiveSeed,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      roundStatus: RoundStatus.inProgress,
      scoreState: ScoreState.initial,
      streakState: StreakState.initial,
      roundTimerState: _initialRoundTimerState(roundTimerConfig, roundNumber),
      strikeTimerState: StrikeTimerState.initial,
      timeBonusTimerState: TimeBonusTimerState.initial,
      bonusSlotsState: initialBonusSlots,
      lastSuccessfulTableauRank: null,
      clearedPeaksAwardedMask: 0,
      bonusAnchorSpawnNonce: 0,
      undoHistory: const <_TriPeaksSnapshot>[],
    );
  }

  TriPeaksState._({
    required List<Card> tableau,
    required List<bool> removed,
    required List<Card> waste,
    required List<Card> stock,
    required this.roundNumber,
    required this.roundSeed,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.roundTimerConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.roundStatus,
    required this.scoreState,
    required this.streakState,
    required this.roundTimerState,
    required this.strikeTimerState,
    required this.timeBonusTimerState,
    required this.bonusSlotsState,
    required this.lastSuccessfulTableauRank,
    required this.clearedPeaksAwardedMask,
    required this.bonusAnchorSpawnNonce,
    required List<_TriPeaksSnapshot> undoHistory,
  })  : tableau = List<Card>.unmodifiable(tableau),
        removed = List<bool>.unmodifiable(removed),
        waste = List<Card>.unmodifiable(waste),
        stock = List<Card>.unmodifiable(stock),
        _undoHistory = List<_TriPeaksSnapshot>.unmodifiable(undoHistory);

  // For each tableau index, these indices must be removed before it is exposed.
  static const List<List<int>> _blockingIndices = <List<int>>[
    <int>[3, 4],
    <int>[5, 6],
    <int>[7, 8],
    <int>[9, 10],
    <int>[10, 11],
    <int>[12, 13],
    <int>[13, 14],
    <int>[15, 16],
    <int>[16, 17],
    <int>[18, 19],
    <int>[19, 20],
    <int>[20, 21],
    <int>[21, 22],
    <int>[22, 23],
    <int>[23, 24],
    <int>[24, 25],
    <int>[25, 26],
    <int>[26, 27],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
    <int>[],
  ];

  static final int _tableauSize = _blockingIndices.length;

  /// Tableau cards in fixed index order.
  final List<Card> tableau;

  /// Whether each tableau position has been removed.
  final List<bool> removed;

  /// Primary waste pile from bottom to top.
  ///
  /// Internally, bonus slot `1` mirrors this pile so slot-based mechanics can
  /// use one consistent representation.
  final List<Card> waste;

  /// Stock pile from next-to-draw at index `0`.
  final List<Card> stock;

  /// 1-based round number for scoring progression.
  final int roundNumber;

  /// Deterministic round seed used for policy-level pseudo-random choices.
  final int roundSeed;

  /// Scoring config used for this round.
  final ScoreConfig scoreConfig;

  /// Mechanics rules used for this round.
  final RoundRulesConfig roundRulesConfig;

  /// Round timer config used for this round.
  final RoundTimerConfig roundTimerConfig;

  /// Undo behavior config.
  final UndoConfig undoConfig;

  /// Streak behavior config.
  final StreakConfig streakConfig;

  /// Strike timer behavior config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Bonus-slots behavior config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Current round lifecycle state.
  final RoundStatus roundStatus;

  /// Current scoring snapshot.
  final ScoreState scoreState;

  /// Current streak tracking snapshot.
  final StreakState streakState;

  /// Current round timer snapshot.
  final RoundTimerState roundTimerState;

  /// Current strike timer snapshot.
  final StrikeTimerState strikeTimerState;

  /// Current time-bonus timer snapshot.
  final TimeBonusTimerState timeBonusTimerState;

  /// Current bonus-slots snapshot.
  final BonusSlotsState bonusSlotsState;

  /// Rank of the last successful tableau-to-slot move.
  final Rank? lastSuccessfulTableauRank;

  /// Bitmask tracking peaks already awarded with clear bonus.
  final int clearedPeaksAwardedMask;

  /// Deterministic nonce consumed by bonus anchor random-rank spawns.
  final int bonusAnchorSpawnNonce;

  /// Peak IDs that already awarded clear bonus.
  Set<int> get clearedPeaksAwarded {
    final out = <int>{};
    for (var peakId = 0; peakId < _peakDefinitions.length; peakId++) {
      if (((clearedPeaksAwardedMask >> peakId) & 1) == 1) {
        out.add(peakId);
      }
    }
    return Set<int>.unmodifiable(out);
  }

  /// Number of available undo steps.
  int get undoStepsAvailable => _undoHistory.length;

  final List<_TriPeaksSnapshot> _undoHistory;

  TriPeaksState _copyWith({
    List<Card>? tableau,
    List<bool>? removed,
    List<Card>? waste,
    List<Card>? stock,
    int? roundNumber,
    int? roundSeed,
    RoundStatus? roundStatus,
    ScoreState? scoreState,
    StreakState? streakState,
    BonusSlotsState? bonusSlotsState,
    RoundTimerState? roundTimerState,
    StrikeTimerState? strikeTimerState,
    TimeBonusTimerState? timeBonusTimerState,
    Rank? lastSuccessfulTableauRank,
    bool clearLastSuccessfulTableauRank = false,
    int? clearedPeaksAwardedMask,
    int? bonusAnchorSpawnNonce,
    List<_TriPeaksSnapshot>? undoHistory,
  }) {
    final nextBonusSlotsState = bonusSlotsState ?? this.bonusSlotsState;
    final syncedWaste =
        waste ?? List<Card>.unmodifiable(nextBonusSlotsState.slots.first);
    return TriPeaksState._(
      tableau: tableau ?? this.tableau,
      removed: removed ?? this.removed,
      waste: syncedWaste,
      stock: stock ?? this.stock,
      roundNumber: roundNumber ?? this.roundNumber,
      roundSeed: roundSeed ?? this.roundSeed,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      roundTimerConfig: roundTimerConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      roundStatus: roundStatus ?? this.roundStatus,
      scoreState: scoreState ?? this.scoreState,
      streakState: streakState ?? this.streakState,
      roundTimerState: roundTimerState ?? this.roundTimerState,
      strikeTimerState: strikeTimerState ?? this.strikeTimerState,
      timeBonusTimerState: timeBonusTimerState ?? this.timeBonusTimerState,
      bonusSlotsState: bonusSlotsState ?? this.bonusSlotsState,
      lastSuccessfulTableauRank: clearLastSuccessfulTableauRank
          ? null
          : (lastSuccessfulTableauRank ?? this.lastSuccessfulTableauRank),
      clearedPeaksAwardedMask:
          clearedPeaksAwardedMask ?? this.clearedPeaksAwardedMask,
      bonusAnchorSpawnNonce:
          bonusAnchorSpawnNonce ?? this.bonusAnchorSpawnNonce,
      undoHistory: undoHistory ?? _undoHistory,
    );
  }

  _TriPeaksSnapshot _toSnapshot() {
    return _TriPeaksSnapshot(
      tableau: tableau,
      removed: removed,
      waste: waste,
      stock: stock,
      roundNumber: roundNumber,
      roundStatus: roundStatus,
      scoreState: scoreState,
      streakState: streakState,
      roundTimerState: roundTimerState,
      strikeTimerState: strikeTimerState,
      timeBonusTimerState: timeBonusTimerState,
      bonusSlotsState: bonusSlotsState,
      lastSuccessfulTableauRank: lastSuccessfulTableauRank,
      clearedPeaksAwardedMask: clearedPeaksAwardedMask,
      bonusAnchorSpawnNonce: bonusAnchorSpawnNonce,
    );
  }

  TriPeaksState _restoreFromSnapshot(_TriPeaksSnapshot snapshot) {
    return _copyWith(
      tableau: snapshot.tableau,
      removed: snapshot.removed,
      waste: snapshot.waste,
      stock: snapshot.stock,
      roundNumber: snapshot.roundNumber,
      roundStatus: snapshot.roundStatus,
      scoreState: snapshot.scoreState,
      streakState: snapshot.streakState,
      roundTimerState: snapshot.roundTimerState,
      strikeTimerState: snapshot.strikeTimerState,
      timeBonusTimerState: snapshot.timeBonusTimerState,
      bonusSlotsState: snapshot.bonusSlotsState,
      lastSuccessfulTableauRank: snapshot.lastSuccessfulTableauRank,
      clearedPeaksAwardedMask: snapshot.clearedPeaksAwardedMask,
      bonusAnchorSpawnNonce: snapshot.bonusAnchorSpawnNonce,
    );
  }

  static bool _areAdjacentRanks(
    Rank left,
    Rank right,
    RoundRulesConfig rules,
  ) {
    if (left.isAdjacentTo(right)) {
      return true;
    }
    final wrap = (left == Rank.ace && right == Rank.king) ||
        (left == Rank.king && right == Rank.ace);
    return rules.aceKingWrapAround && wrap;
  }

  static const List<List<int>> _peakDefinitions = <List<int>>[
    <int>[0, 3, 4, 9, 10, 11, 18, 19, 20, 21],
    <int>[1, 5, 6, 12, 13, 14, 21, 22, 23, 24],
    <int>[2, 7, 8, 15, 16, 17, 24, 25, 26, 27],
  ];

  static int _computeStockSize(int roundNumber, RoundRulesConfig rules) {
    final decrease = roundNumber ~/ rules.stockDecreaseEveryRounds;
    final size = rules.startStockSize - decrease;
    return size < rules.minStockSize ? rules.minStockSize : size;
  }

  static void _validateDeck(List<Card> deck) {
    if (deck.length != 52) {
      throw ArgumentError.value(deck.length, 'deck.length', 'Must be 52.');
    }
    final unique = deck.toSet();
    if (unique.length != 52) {
      throw ArgumentError('Deck must contain 52 unique cards.');
    }
  }

  void _assertValidIndex(int index) {
    if (index < 0 || index >= _tableauSize) {
      throw RangeError.index(index, tableau, 'index', null, _tableauSize);
    }
  }

  /// Serializes round state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_round_state',
      'tableau': tableau.map((card) => card.toMap()).toList(growable: false),
      'removed': removed,
      'waste': waste.map((card) => card.toMap()).toList(growable: false),
      'stock': stock.map((card) => card.toMap()).toList(growable: false),
      'roundNumber': roundNumber,
      'roundSeed': roundSeed,
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'roundStatus': roundStatus.name,
      'scoreState': scoreState.toMap(),
      'streakState': streakState.toMap(),
      'roundTimerState': roundTimerState.toMap(),
      'strikeTimerState': strikeTimerState.toMap(),
      'timeBonusTimerState': timeBonusTimerState.toMap(),
      'bonusSlotsState': bonusSlotsState.toMap(),
      if (lastSuccessfulTableauRank case final rank?)
        'lastSuccessfulTableauRank': rank.name,
      'clearedPeaksAwardedMask': clearedPeaksAwardedMask,
      'bonusAnchorSpawnNonce': bonusAnchorSpawnNonce,
      'undoHistory': _undoHistory
          .map((snapshot) => snapshot.toMap())
          .toList(growable: false),
    };
  }

  /// Decodes round state from map without throwing.
  static DecodeResult<TriPeaksState> tryFromMap(Map<String, dynamic> map) {
    return _triPeaksStateTryFromMap(map);
  }

  static DecodeResult<List<Card>> _decodeCardList(Object? raw, String name) {
    return _decodeCardListFromRaw(raw, name);
  }
}
