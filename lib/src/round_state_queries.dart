part of '../tripeaks_engine.dart';

extension TriPeaksStateQueries on TriPeaksState {
  /// Remaining stock size.
  int get stockCount => stock.length;

  /// Number of cards currently in the waste pile.
  int get wasteCount => waste.length;

  /// Top card of the primary waste pile.
  ///
  /// Internally, waste is mirrored by bonus slot `1` so slot-based mechanics
  /// can use one consistent model.
  Card get wasteTop => bonusSlotsState.slots.first.last;

  /// Returns a view of cards in tableau index order.
  ///
  /// Removed positions are returned as `null`.
  List<Card?> get tableauSnapshot {
    return List<Card?>.generate(
      TriPeaksState._tableauSize,
      (index) => removed[index] ? null : tableau[index],
      growable: false,
    );
  }

  /// Returns `true` if all tableau cards for the active layout are removed.
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
      TriPeaksState._tableauSize,
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
    return TriPeaksState._blockingIndices[index]
        .every((blocker) => removed[blocker]);
  }

  /// Returns `true` if [index] can be moved onto a target playable pile.
  ///
  /// If [targetSlot] is omitted, this checks open piles in priority
  /// `1 -> 2 -> 3` and returns `true` when at least one currently open pile can
  /// accept the move.
  bool canRemoveTableau(int index, {int? targetSlot}) {
    if (index < 0 || index >= TriPeaksState._tableauSize) {
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

  /// Returns whether [slotIndex] is currently open now.
  bool isBonusSlotOpen(int slotIndex) {
    if (!isBonusSlotIndexInRange(slotIndex)) {
      return false;
    }
    return slotIndex <= bonusSlotsState.openSlotsCount;
  }

  /// Returns whether [UseBonusSlotAction] is currently valid for [slotIndex].
  bool canUseBonusSlot(int slotIndex) {
    return isBonusSlotIndexInRange(slotIndex) && isBonusSlotOpen(slotIndex);
  }

  /// Bonus-slot indices accepted by [UseBonusSlotAction] right now.
  ///
  /// Prefer this for consumer-facing "what can be used now" queries instead of
  /// inferring from [BonusSlotsState.openSlotsCount].
  List<int> get actionableBonusSlotIndices {
    final out = <int>[];
    for (var slotIndex = 1;
        slotIndex <= bonusSlotsConfig.maxSlots;
        slotIndex++) {
      if (canUseBonusSlot(slotIndex)) {
        out.add(slotIndex);
      }
    }
    return List<int>.unmodifiable(out);
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
    return TriPeaksState._areAdjacentRanks(
      candidate,
      topCard.rank,
      roundRulesConfig,
    );
  }

  /// Whether the next stock card can be drawn onto the waste pile.
  bool get canDrawFromStock => stock.isNotEmpty;
}
