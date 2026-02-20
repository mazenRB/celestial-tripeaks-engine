part of '../tripeaks_engine.dart';

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
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
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
    final initialWaste = workingDeck[_tableauSize];
    final initialBonusSlots = BonusSlotsState.initial.copyWith(
      slots: <List<Card>>[
        <Card>[initialWaste],
        <Card>[],
        <Card>[],
      ],
    );

    return TriPeaksState._(
      tableau: workingDeck.take(_tableauSize).toList(growable: false),
      removed: List<bool>.filled(_tableauSize, false, growable: false),
      waste: <Card>[initialWaste],
      stock: workingDeck.skip(_tableauSize + 1).toList(growable: false),
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      scoreState: ScoreState.initial,
      streakState: StreakState.initial,
      strikeTimerState: StrikeTimerState.initial,
      bonusSlotsState: initialBonusSlots,
      lastSuccessfulTableauRank: null,
      clearedPeaksAwardedMask: 0,
      undoHistory: const <_TriPeaksSnapshot>[],
    );
  }

  TriPeaksState._({
    required List<Card> tableau,
    required List<bool> removed,
    required List<Card> waste,
    required List<Card> stock,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.scoreState,
    required this.streakState,
    required this.strikeTimerState,
    required this.bonusSlotsState,
    required this.lastSuccessfulTableauRank,
    required this.clearedPeaksAwardedMask,
    required List<_TriPeaksSnapshot> undoHistory,
  })  : tableau = List<Card>.unmodifiable(tableau),
        removed = List<bool>.unmodifiable(removed),
        waste = List<Card>.unmodifiable(waste),
        stock = List<Card>.unmodifiable(stock),
        _undoHistory = List<_TriPeaksSnapshot>.unmodifiable(undoHistory);

  static const int _tableauSize = 28;

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

  /// Tableau cards in fixed index order.
  final List<Card> tableau;

  /// Whether each tableau position has been removed.
  final List<bool> removed;

  /// Primary waste pile from bottom to top (bonus slot 1).
  final List<Card> waste;

  /// Stock pile from next-to-draw at index `0`.
  final List<Card> stock;

  /// Scoring config used for this round.
  final ScoreConfig scoreConfig;

  /// Mechanics rules used for this round.
  final RoundRulesConfig roundRulesConfig;

  /// Undo behavior config.
  final UndoConfig undoConfig;

  /// Streak behavior config.
  final StreakConfig streakConfig;

  /// Strike timer behavior config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Bonus-slots behavior config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Current scoring snapshot.
  final ScoreState scoreState;

  /// Current streak tracking snapshot.
  final StreakState streakState;

  /// Current strike timer snapshot.
  final StrikeTimerState strikeTimerState;

  /// Current bonus-slots snapshot.
  final BonusSlotsState bonusSlotsState;

  /// Rank of the last successful tableau-to-slot move.
  final Rank? lastSuccessfulTableauRank;

  /// Bitmask tracking peaks already awarded with clear bonus.
  final int clearedPeaksAwardedMask;

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

  /// Remaining stock size.
  int get stockCount => stock.length;

  /// Number of cards currently in the waste pile.
  int get wasteCount => waste.length;

  /// Top card of bonus slot 1 (legacy waste-top access).
  Card get wasteTop => bonusSlotsState.slots.first.last;

  /// Returns a view of cards in tableau index order.
  ///
  /// Removed positions are returned as `null`.
  List<Card?> get tableauSnapshot {
    return List<Card?>.generate(
      _tableauSize,
      (index) => removed[index] ? null : tableau[index],
      growable: false,
    );
  }

  /// Returns `true` if all 28 tableau cards have been removed.
  bool get isWon => removed.every((isRemoved) => isRemoved);

  /// Returns `true` if there are no legal moves and no stock draw available.
  bool get isLost {
    if (isWon) {
      return false;
    }
    return stock.isEmpty && availableMoves.removableTableauIndices.isEmpty;
  }

  /// Returns indices of currently exposed tableau cards.
  List<int> get exposedTableauIndices {
    return List<int>.generate(
      _tableauSize,
      (index) => index,
      growable: false,
    ).where(isExposed).toList(growable: false);
  }

  /// Returns a snapshot of currently legal actions.
  TriPeaksMoves get availableMoves {
    final removable = <int>[];
    for (final index in exposedTableauIndices) {
      if (canRemoveTableau(index)) {
        removable.add(index);
      }
    }
    return TriPeaksMoves(
      removableTableauIndices: List<int>.unmodifiable(removable),
      canDrawFromStock: canDrawFromStock,
    );
  }

  /// Returns `true` when a tableau position is not removed and not blocked.
  bool isExposed(int index) {
    _assertValidIndex(index);
    if (removed[index]) {
      return false;
    }
    return _blockingIndices[index].every((blocker) => removed[blocker]);
  }

  /// Returns `true` if [index] can be moved onto a target bonus slot.
  ///
  /// If [targetSlot] is omitted, this checks open slots in priority `1 -> 2 -> 3`
  /// and returns `true` when at least one slot can accept the move.
  bool canRemoveTableau(int index, {int? targetSlot}) {
    if (index < 0 || index >= _tableauSize) {
      return false;
    }
    if (!isExposed(index)) {
      return false;
    }
    final candidate = tableau[index];
    if (targetSlot case final explicitSlot?) {
      final topCard = _slotTop(explicitSlot);
      if (topCard == null) {
        return false;
      }
      return _canPlaceOnSlotTop(candidate.rank, topCard);
    }

    for (var slot = 1; slot <= bonusSlotsState.openSlotsCount; slot++) {
      final topCard = _slotTop(slot);
      if (topCard == null) {
        continue;
      }
      if (_canPlaceOnSlotTop(candidate.rank, topCard)) {
        return true;
      }
    }
    return false;
  }

  /// Returns whether [slotIndex] is a valid bonus slot index.
  bool isBonusSlotIndexInRange(int slotIndex) {
    return slotIndex >= 1 && slotIndex <= bonusSlotsConfig.maxSlots;
  }

  /// Returns whether [slotIndex] is currently open.
  bool isBonusSlotOpen(int slotIndex) {
    if (!isBonusSlotIndexInRange(slotIndex)) {
      return false;
    }
    return slotIndex <= bonusSlotsState.openSlotsCount;
  }

  Card? _slotTop(int slotIndex) {
    if (!isBonusSlotOpen(slotIndex)) {
      return null;
    }
    final slot = bonusSlotsState.slots[slotIndex - 1];
    if (slot.isEmpty) {
      return null;
    }
    return slot.last;
  }

  bool _canPlaceOnSlotTop(Rank candidate, Card topCard) {
    if (topCard.isJoker) {
      return bonusSlotsConfig.jokerAcceptsAnyRank;
    }
    return _areAdjacentRanks(
      candidate,
      topCard.rank,
      roundRulesConfig,
    );
  }

  /// Whether the next stock card can be drawn to waste.
  bool get canDrawFromStock => stock.isNotEmpty;

  TriPeaksState _copyWith({
    List<Card>? tableau,
    List<bool>? removed,
    List<Card>? waste,
    List<Card>? stock,
    ScoreState? scoreState,
    StreakState? streakState,
    BonusSlotsState? bonusSlotsState,
    StrikeTimerState? strikeTimerState,
    Rank? lastSuccessfulTableauRank,
    bool clearLastSuccessfulTableauRank = false,
    int? clearedPeaksAwardedMask,
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
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      scoreState: scoreState ?? this.scoreState,
      streakState: streakState ?? this.streakState,
      strikeTimerState: strikeTimerState ?? this.strikeTimerState,
      bonusSlotsState: bonusSlotsState ?? this.bonusSlotsState,
      lastSuccessfulTableauRank: clearLastSuccessfulTableauRank
          ? null
          : (lastSuccessfulTableauRank ?? this.lastSuccessfulTableauRank),
      clearedPeaksAwardedMask:
          clearedPeaksAwardedMask ?? this.clearedPeaksAwardedMask,
      undoHistory: undoHistory ?? _undoHistory,
    );
  }

  _TriPeaksSnapshot _toSnapshot() {
    return _TriPeaksSnapshot(
      tableau: tableau,
      removed: removed,
      waste: waste,
      stock: stock,
      scoreState: scoreState,
      streakState: streakState,
      strikeTimerState: strikeTimerState,
      bonusSlotsState: bonusSlotsState,
      lastSuccessfulTableauRank: lastSuccessfulTableauRank,
      clearedPeaksAwardedMask: clearedPeaksAwardedMask,
    );
  }

  TriPeaksState _restoreFromSnapshot(_TriPeaksSnapshot snapshot) {
    return _copyWith(
      tableau: snapshot.tableau,
      removed: snapshot.removed,
      waste: snapshot.waste,
      stock: snapshot.stock,
      scoreState: snapshot.scoreState,
      streakState: snapshot.streakState,
      strikeTimerState: snapshot.strikeTimerState,
      bonusSlotsState: snapshot.bonusSlotsState,
      lastSuccessfulTableauRank: snapshot.lastSuccessfulTableauRank,
      clearedPeaksAwardedMask: snapshot.clearedPeaksAwardedMask,
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
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'scoreState': scoreState.toMap(),
      'streakState': streakState.toMap(),
      'strikeTimerState': strikeTimerState.toMap(),
      'bonusSlotsState': bonusSlotsState.toMap(),
      if (lastSuccessfulTableauRank case final rank?)
        'lastSuccessfulTableauRank': rank.name,
      'clearedPeaksAwardedMask': clearedPeaksAwardedMask,
      'undoHistory': _undoHistory
          .map((snapshot) => snapshot.toMap())
          .toList(growable: false),
    };
  }

  /// Decodes round state from map without throwing.
  static DecodeResult<TriPeaksState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'tripeaks_round_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final tableauResult = _decodeCardList(map['tableau'], 'tableau');
    if (!tableauResult.isSuccess) {
      return DecodeResult.failure(tableauResult.error!);
    }
    final wasteResult = _decodeCardList(map['waste'], 'waste');
    if (!wasteResult.isSuccess) {
      return DecodeResult.failure(wasteResult.error!);
    }
    final stockResult = _decodeCardList(map['stock'], 'stock');
    if (!stockResult.isSuccess) {
      return DecodeResult.failure(stockResult.error!);
    }

    final removed = map['removed'];
    if (removed is! List<dynamic> || removed.any((item) => item is! bool)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'removed must be a list of bool.',
        ),
      );
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
    final bonusSlotsConfigResult = BonusSlotsConfig.tryFromMap(
      bonusSlotsConfigMap,
    );
    if (!bonusSlotsConfigResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfigResult.error!);
    }
    final scoreStateMap = map['scoreState'];
    if (scoreStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'scoreState must be a map.',
        ),
      );
    }
    final scoreStateResult = ScoreState.tryFromMap(scoreStateMap);
    if (!scoreStateResult.isSuccess) {
      return DecodeResult.failure(scoreStateResult.error!);
    }
    final streakStateMap = map['streakState'];
    if (streakStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'streakState must be a map.',
        ),
      );
    }
    final streakStateResult = StreakState.tryFromMap(streakStateMap);
    if (!streakStateResult.isSuccess) {
      return DecodeResult.failure(streakStateResult.error!);
    }
    final strikeTimerStateMap = map['strikeTimerState'];
    if (strikeTimerStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'strikeTimerState must be a map.',
        ),
      );
    }
    final strikeTimerStateResult = StrikeTimerState.tryFromMap(
      strikeTimerStateMap,
    );
    if (!strikeTimerStateResult.isSuccess) {
      return DecodeResult.failure(strikeTimerStateResult.error!);
    }
    final lastSuccessfulTableauRank = map['lastSuccessfulTableauRank'];
    if (lastSuccessfulTableauRank != null &&
        lastSuccessfulTableauRank is! String) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'lastSuccessfulTableauRank must be a string when present.',
        ),
      );
    }
    Rank? decodedLastSuccessfulTableauRank;
    if (lastSuccessfulTableauRank case final rankName?) {
      try {
        decodedLastSuccessfulTableauRank = Rank.values.byName(rankName);
      } on Object catch (error) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Invalid lastSuccessfulTableauRank: $error',
          ),
        );
      }
    }
    final bonusSlotsStateMap = map['bonusSlotsState'];
    if (bonusSlotsStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'bonusSlotsState must be a map.',
        ),
      );
    }
    final bonusSlotsStateResult = BonusSlotsState.tryFromMap(
      bonusSlotsStateMap,
    );
    if (!bonusSlotsStateResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsStateResult.error!);
    }
    final clearedPeaksAwardedMask = map['clearedPeaksAwardedMask'];
    if (clearedPeaksAwardedMask != null && clearedPeaksAwardedMask is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'clearedPeaksAwardedMask must be int when present.',
        ),
      );
    }

    final historyRaw = map['undoHistory'];
    if (historyRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'undoHistory must be a list.',
        ),
      );
    }
    final history = <_TriPeaksSnapshot>[];
    for (final item in historyRaw) {
      if (item is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'undoHistory items must be maps.',
          ),
        );
      }
      final snapshotResult = _TriPeaksSnapshot.tryFromMap(item);
      if (!snapshotResult.isSuccess) {
        return DecodeResult.failure(snapshotResult.error!);
      }
      history.add(snapshotResult.value!);
    }

    final decodedBonusSlots = bonusSlotsStateResult.value!;
    final normalizedSlots = <List<Card>>[
      ...decodedBonusSlots.slots,
    ];
    if (normalizedSlots.first.isEmpty && wasteResult.value!.isNotEmpty) {
      normalizedSlots[0] = wasteResult.value!;
    }
    final normalizedBonusSlots = decodedBonusSlots.copyWith(
      slots: List<List<Card>>.unmodifiable(
        normalizedSlots
            .map((slot) => List<Card>.unmodifiable(slot))
            .toList(growable: false),
      ),
    );
    final normalizedWaste = List<Card>.unmodifiable(normalizedSlots.first);

    return DecodeResult.success(
      TriPeaksState._(
        tableau: tableauResult.value!,
        removed: removed.cast<bool>(),
        waste: normalizedWaste,
        stock: stockResult.value!,
        scoreConfig: scoreConfigResult.value!,
        roundRulesConfig: roundRulesResult.value!,
        undoConfig: undoConfigResult.value!,
        streakConfig: streakConfigResult.value!,
        strikeTimerConfig: strikeTimerConfigResult.value!,
        bonusSlotsConfig: bonusSlotsConfigResult.value!,
        scoreState: scoreStateResult.value!,
        streakState: streakStateResult.value!,
        strikeTimerState: strikeTimerStateResult.value!,
        bonusSlotsState: normalizedBonusSlots,
        lastSuccessfulTableauRank: decodedLastSuccessfulTableauRank,
        clearedPeaksAwardedMask: clearedPeaksAwardedMask as int? ?? 0,
        undoHistory: history,
      ),
    );
  }

  static DecodeResult<List<Card>> _decodeCardList(Object? raw, String name) {
    if (raw is! List<dynamic>) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: '$name must be a list.',
        ),
      );
    }
    final cards = <Card>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: '$name items must be maps.',
          ),
        );
      }
      final decoded = Card.tryFromMap(item);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      cards.add(decoded.value!);
    }
    return DecodeResult.success(List<Card>.unmodifiable(cards));
  }
}
