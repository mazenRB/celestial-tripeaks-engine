part of '../tripeaks_engine.dart';

BonusSlotsState _withRecomputedOpenSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  final openSlotsCount = _computeOpenSlotsCount(streakState, config);
  if (config.spawnPolicy == BonusSlotSpawnPolicy.stockTopCard &&
      openSlotsCount > state.openSlotsCount) {
    return state;
  }
  return _withOpenSlotsCount(state, openSlotsCount);
}

({BonusSlotsState bonusSlotsState, int nextSpawnNonce, List<Card> stock})
    _withRecomputedOpenSlotsAndSpawn(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
  Rank? lastSuccessfulTableauRank,
  int roundSeed,
  int spawnNonce,
  List<Card> stock,
) {
  final openSlotsCount = _computeOpenSlotsCount(streakState, config);
  if (openSlotsCount <= state.openSlotsCount) {
    return (
      bonusSlotsState: _withOpenSlotsCount(state, openSlotsCount),
      nextSpawnNonce: spawnNonce,
      stock: stock,
    );
  }

  final nextSlots = <List<Card>>[
    List<Card>.from(state.slots[0]),
    List<Card>.from(state.slots[1]),
    List<Card>.from(state.slots[2]),
  ];
  final nextStock = List<Card>.from(stock);
  var nextOpenSlotsCount = state.openSlotsCount;

  var nextSpawnNonce = spawnNonce;
  for (var slotIndex = state.openSlotsCount + 1;
      slotIndex <= openSlotsCount;
      slotIndex++) {
    if (config.spawnPolicy == BonusSlotSpawnPolicy.stockTopCard &&
        slotIndex > 1 &&
        nextStock.isEmpty) {
      break;
    }
    if (nextSlots[slotIndex - 1].isEmpty) {
      if (config.spawnPolicy == BonusSlotSpawnPolicy.stockTopCard &&
          slotIndex > 1) {
        nextSlots[slotIndex - 1].add(nextStock.removeAt(0));
      } else {
        nextSlots[slotIndex - 1].add(
          _spawnOpenSlotAnchor(
            config,
            lastSuccessfulTableauRank,
            roundSeed: roundSeed,
            spawnNonce: nextSpawnNonce,
            slotIndex: slotIndex,
          ),
        );
        nextSpawnNonce++;
      }
    }
    nextOpenSlotsCount = slotIndex;
  }

  return (
    bonusSlotsState: state.copyWith(
      openSlotsCount: nextOpenSlotsCount,
      slots: List<List<Card>>.unmodifiable(
        nextSlots.map((slot) => List<Card>.unmodifiable(slot)).toList(),
      ),
    ),
    nextSpawnNonce: nextSpawnNonce,
    stock: List<Card>.unmodifiable(nextStock),
  );
}

BonusSlotsState _onDrawBonusSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  if (!config.enabled) {
    return _withOpenSlotsCount(state, 1);
  }
  if (config.closeOnDraw) {
    return _withOpenSlotsCount(
      state,
      _computeOpenSlotsCount(streakState, config),
    );
  }
  return _withRecomputedOpenSlots(state, config, streakState);
}

BonusSlotsState _onInvalidActionBonusSlots(
  BonusSlotsState state,
  BonusSlotsConfig config,
  StreakState streakState,
) {
  if (!config.enabled) {
    return _withOpenSlotsCount(state, 1);
  }
  if (config.closeOnInvalidAction) {
    return _withOpenSlotsCount(
      state,
      _computeOpenSlotsCount(streakState, config),
    );
  }
  return _withRecomputedOpenSlots(state, config, streakState);
}

BonusSlotsState _withOpenSlotsCount(BonusSlotsState state, int openSlotsCount) {
  if (openSlotsCount >= state.openSlotsCount) {
    return state.copyWith(openSlotsCount: openSlotsCount);
  }
  final merged = <List<Card>>[
    List<Card>.from(state.slots[0]),
    List<Card>.from(state.slots[1]),
    List<Card>.from(state.slots[2]),
  ];
  final movedToSlot1Bottom = <Card>[];
  for (var slot = openSlotsCount + 1; slot <= 3; slot++) {
    final from = merged[slot - 1];
    if (from.isEmpty) {
      continue;
    }
    for (final card in from) {
      if (!card.isJoker) {
        movedToSlot1Bottom.add(card);
      }
    }
    merged[slot - 1] = <Card>[];
  }
  if (movedToSlot1Bottom.isNotEmpty) {
    merged[0] = <Card>[
      ...movedToSlot1Bottom,
      ...merged[0],
    ];
  }
  return state.copyWith(
    openSlotsCount: openSlotsCount,
    slots: List<List<Card>>.unmodifiable(
      merged.map((slot) => List<Card>.unmodifiable(slot)).toList(),
    ),
  );
}

List<List<Card>> _appendCardToSlot(
  List<List<Card>> slots,
  int slotIndex,
  Card card,
) {
  final next = <List<Card>>[
    List<Card>.from(slots[0]),
    List<Card>.from(slots[1]),
    List<Card>.from(slots[2]),
  ];
  next[slotIndex - 1].add(card);
  return List<List<Card>>.unmodifiable(
    next.map((slot) => List<Card>.unmodifiable(slot)).toList(),
  );
}

List<List<Card>> _appendTableauCardToSlot(
  List<List<Card>> slots,
  int slotIndex,
  Card card,
  BonusSlotsConfig config,
) {
  var next = _appendCardToSlot(slots, slotIndex, card);
  final slot = next[slotIndex - 1];
  final previousTop = slot.length >= 2 ? slot[slot.length - 2] : null;
  final shouldConsumePreviousTop = previousTop != null &&
      ((previousTop.isJoker && config.jokerConsumedOnFirstUse) ||
          previousTop.isAnchor);
  if (slot.length >= 2 && shouldConsumePreviousTop) {
    final mutable = <List<Card>>[
      List<Card>.from(next[0]),
      List<Card>.from(next[1]),
      List<Card>.from(next[2]),
    ];
    mutable[slotIndex - 1].removeAt(mutable[slotIndex - 1].length - 2);
    next = List<List<Card>>.unmodifiable(
      mutable.map((s) => List<Card>.unmodifiable(s)).toList(),
    );
  }
  return next;
}

Card _spawnOpenSlotAnchor(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank, {
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
}) {
  switch (config.spawnPolicy) {
    case BonusSlotSpawnPolicy.joker:
      return const Card.joker();
    case BonusSlotSpawnPolicy.tierFixedRank:
      return Card.anchor(
        _tierFixedAnchorRank(config, lastSuccessfulRank),
      );
    case BonusSlotSpawnPolicy.tierRandomRank:
      return Card.anchor(
        _tierRandomAnchorRank(
          config,
          lastSuccessfulRank,
          roundSeed: roundSeed,
          spawnNonce: spawnNonce,
          slotIndex: slotIndex,
        ),
      );
    case BonusSlotSpawnPolicy.stockTopCard:
      throw StateError(
        'stockTopCard spawn policy must consume stock in the reducer.',
      );
  }
}

Rank _tierFixedAnchorRank(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank,
) {
  final tier = _tierForLastSuccessfulRank(
    lastSuccessfulRank,
    config.defaultAnchorTierWhenUnknown,
  );
  switch (tier) {
    case BonusSlotAnchorTier.low:
      return config.lowTierAnchorRank;
    case BonusSlotAnchorTier.high:
      return config.highTierAnchorRank;
  }
}

const List<Rank> _lowTierAnchorRanks = <Rank>[
  Rank.two,
  Rank.three,
  Rank.four,
  Rank.five,
  Rank.six,
  Rank.seven,
  Rank.eight,
  Rank.nine,
  Rank.ten,
];

const List<Rank> _highTierAnchorRanks = <Rank>[
  Rank.ace,
  Rank.jack,
  Rank.queen,
  Rank.king,
];

const int _tierMixLow = 1;
const int _tierMixHigh = 2;

Rank _tierRandomAnchorRank(
  BonusSlotsConfig config,
  Rank? lastSuccessfulRank, {
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
}) {
  final tier = _tierForLastSuccessfulRank(
    lastSuccessfulRank,
    config.defaultAnchorTierWhenUnknown,
  );
  final (tierDiscriminator, domain) = switch (tier) {
    BonusSlotAnchorTier.low => (_tierMixLow, _lowTierAnchorRanks),
    BonusSlotAnchorTier.high => (_tierMixHigh, _highTierAnchorRanks),
  };
  final index = _deterministicIndex(
    roundSeed: roundSeed,
    spawnNonce: spawnNonce,
    slotIndex: slotIndex,
    tierDiscriminator: tierDiscriminator,
    domainSize: domain.length,
  );
  return domain[index];
}

int _deterministicIndex({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required int tierDiscriminator,
  required int domainSize,
}) {
  var x = 0x9e3779b9;
  x ^= roundSeed;
  x = _mix32(x + 0x85ebca6b);
  x ^= (spawnNonce + 1) * 0x27d4eb2d;
  x = _mix32(x);
  x ^= slotIndex * 0x165667b1;
  x = _mix32(x + (tierDiscriminator * 0x9e3779b1));
  return (x & 0x7fffffff) % domainSize;
}

int _mix32(int value) {
  var x = value & 0xffffffff;
  x ^= (x >> 16);
  x = (x * 0x7feb352d) & 0xffffffff;
  x ^= (x >> 15);
  x = (x * 0x846ca68b) & 0xffffffff;
  x ^= (x >> 16);
  return x & 0xffffffff;
}

BonusSlotAnchorTier _tierForLastSuccessfulRank(
  Rank? lastSuccessfulRank,
  BonusSlotAnchorTier whenUnknown,
) {
  final rank = lastSuccessfulRank;
  if (rank == null) {
    return whenUnknown;
  }
  if (rank.value >= 2 && rank.value <= 10) {
    return BonusSlotAnchorTier.low;
  }
  return BonusSlotAnchorTier.high;
}

int _resolveTargetSlotForDraw(TriPeaksState state, int? targetSlot) {
  // Draw actions always target slot 1.
  return 1;
}

int _resolveTargetSlotForTableauMove(
  TriPeaksState state,
  int index,
  int? targetSlot,
) {
  if (targetSlot case final explicit?) {
    return explicit;
  }
  for (var slot = 1; slot <= state.bonusSlotsState.openSlotsCount; slot++) {
    if (state.canRemoveTableau(index, targetSlot: slot)) {
      return slot;
    }
  }
  return 1;
}

int _computeOpenSlotsCount(
  StreakState streakState,
  BonusSlotsConfig config,
) {
  if (!config.enabled) {
    return 1;
  }

  var open = 1;
  if (streakState.currentStreak >= config.spawnOnOpenSlot2AtStreak) {
    open = 2;
  }
  if (streakState.currentStreak >= config.spawnOnOpenSlot3AtStreak) {
    open = 3;
  }
  if (open < 1) {
    return 1;
  }
  if (open > config.maxSlots) {
    return config.maxSlots;
  }
  return open;
}
