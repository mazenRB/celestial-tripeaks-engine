part of '../tripeaks_engine.dart';

extension TriPeaksStateQueries on TriPeaksState {
  /// Resolved round lifecycle state.
  RoundStatus get status {
    if (roundStatus == RoundStatus.timedOut) {
      return RoundStatus.timedOut;
    }
    if (removed.every((isRemoved) => isRemoved)) {
      return RoundStatus.won;
    }
    if (isRoundTimerAwaitingStart) {
      return RoundStatus.inProgress;
    }
    return stock.isEmpty && _removableTableauIndicesIgnoringTimer().isEmpty
        ? RoundStatus.lost
        : RoundStatus.inProgress;
  }

  /// Whether the round ended because its countdown reached zero.
  bool get isTimedOut => status == RoundStatus.timedOut;

  /// Whether the countdown is configured and waiting for explicit start.
  bool get isRoundTimerAwaitingStart {
    if (!roundTimerConfig.enabled) {
      return false;
    }
    final duration = _roundTimerDurationForRound(roundTimerConfig, roundNumber);
    return duration > 0 && !roundTimerState.isStarted;
  }

  /// Whether gameplay actions are currently allowed.
  bool get isGameplayEnabled {
    return status == RoundStatus.inProgress && !isRoundTimerAwaitingStart;
  }

  /// Configured duration for the current round in whole seconds.
  int get configuredRoundDurationSeconds {
    return _roundTimerDurationForRound(roundTimerConfig, roundNumber);
  }

  /// Whether this round uses a positive countdown duration.
  bool get hasActiveRoundTimer {
    return roundTimerConfig.enabled && configuredRoundDurationSeconds > 0;
  }

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
  bool get isWon => status == RoundStatus.won;

  /// Returns `true` if there are no legal moves and no stock draw available.
  bool get isLost => status == RoundStatus.lost;

  /// Returns `true` if the round reached a terminal state.
  bool get isFinished => status != RoundStatus.inProgress;

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
    if (!isGameplayEnabled) {
      return const TriPeaksMoves(
        removableTableauIndices: <int>[],
        canDrawFromStock: false,
      );
    }
    final removable = <int>[];
    for (final index in exposedTableauIndices) {
      if (_canRemoveTableauIgnoringGameplayAvailability(index)) {
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
    if (!isGameplayEnabled) {
      return false;
    }
    return _canRemoveTableauIgnoringGameplayAvailability(
      index,
      targetSlot: targetSlot,
    );
  }

  bool _canRemoveTableauIgnoringGameplayAvailability(
    int index, {
    int? targetSlot,
  }) {
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
    return isGameplayEnabled &&
        isBonusSlotIndexInRange(slotIndex) &&
        isBonusSlotOpen(slotIndex);
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
  bool get canDrawFromStock => isGameplayEnabled && stock.isNotEmpty;

  List<int> _removableTableauIndicesIgnoringTimer() {
    final removable = <int>[];
    for (final index in exposedTableauIndices) {
      if (_canRemoveTableauIgnoringGameplayAvailability(index)) {
        removable.add(index);
      }
    }
    return removable;
  }
}
