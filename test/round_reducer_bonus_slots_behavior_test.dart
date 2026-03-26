import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - bonus slots behavior', () {
    test(
      'placing any tableau card onto joker slot is accepted and consumes joker',
      () {
        var state = TriPeaksState.newGame(
          deck: buildJokerConsumeDeck(),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.joker,
          ),
        );
        state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
        state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
        state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
        expect(state.bonusSlotsState.slots[1].single.isJoker, isTrue);

        final result = tryReduceTriPeaks(
          state,
          const RemoveTableauCardAction(21, targetSlot: 2),
        );
        expect(result.isSuccess, isTrue);
        expect(result.state.bonusSlotsState.slots[1].length, 1);
        expect(result.state.bonusSlotsState.slots[1].last.isJoker, isFalse);
      },
    );

    test('closing slots removes unused jokers and merges real cards', () {
      var state = TriPeaksState.newGame(
        deck: buildJokerConsumeDeck(),
        streakConfig: const StreakConfig(resetOnDraw: true),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      expect(state.bonusSlotsState.slots[1].single.isJoker, isTrue);

      state = reduceTriPeaks(state, const DrawFromStockAction());
      expect(state.bonusSlotsState.openSlotsCount, 1);
      expect(state.bonusSlotsState.slots[1], isEmpty);
      expect(state.bonusSlotsState.slots[2], isEmpty);
      expect(
        state.bonusSlotsState.slots[0].any((card) => card.isJoker),
        isFalse,
      );
    });

    test('closing slots keeps slot1 top card stable', () {
      var state = TriPeaksState.newGame(
        deck: buildJokerConsumeDeck(),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      state = reduceTriPeaks(
        state,
        const RemoveTableauCardAction(21, targetSlot: 2),
      );
      final slot1TopBefore = state.bonusSlotsState.slots[0].last;
      final slot2TopBefore = state.bonusSlotsState.slots[1].last;
      expect(slot2TopBefore.isJoker, isFalse);

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(0),
      );
      expect(invalid.isSuccess, isFalse);
      expect(invalid.state.bonusSlotsState.openSlotsCount, 1);
      expect(invalid.state.bonusSlotsState.slots[0].last, slot1TopBefore);
    });

    test('draw/invalid can close bonus slots based on config', () {
      var drawState = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        streakConfig: const StreakConfig(resetOnDraw: true),
        bonusSlotsConfig: const BonusSlotsConfig(
          closeOnDraw: true,
          closeOnInvalidAction: true,
        ),
      );
      drawState = reduceTriPeaks(drawState, const RemoveTableauCardAction(18));
      drawState = reduceTriPeaks(drawState, const RemoveTableauCardAction(19));
      drawState = reduceTriPeaks(drawState, const RemoveTableauCardAction(20));
      expect(drawState.bonusSlotsState.openSlotsCount, 2);
      drawState = reduceTriPeaks(drawState, const DrawFromStockAction());
      expect(drawState.streakState.currentStreak, 0);
      expect(drawState.bonusSlotsState.openSlotsCount, 1);

      var invalidState = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
        bonusSlotsConfig: const BonusSlotsConfig(
          closeOnDraw: true,
          closeOnInvalidAction: true,
        ),
      );
      invalidState =
          reduceTriPeaks(invalidState, const RemoveTableauCardAction(18));
      invalidState =
          reduceTriPeaks(invalidState, const RemoveTableauCardAction(19));
      invalidState =
          reduceTriPeaks(invalidState, const RemoveTableauCardAction(20));
      expect(invalidState.bonusSlotsState.openSlotsCount, 2);
      final invalid = tryReduceTriPeaks(
        invalidState,
        const RemoveTableauCardAction(99),
      );
      expect(invalid.isSuccess, isFalse);
      expect(invalid.state.streakState.currentStreak, 0);
      expect(invalid.state.bonusSlotsState.openSlotsCount, 1);
    });

    test('undo restores bonus slots state', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        undoConfig: const UndoConfig(maxSteps: 10),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      expect(state.bonusSlotsState.openSlotsCount, 2);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.streakState.currentStreak, 2);
      expect(state.bonusSlotsState.openSlotsCount, 1);
      expect(state.bonusSlotsState.slots[0].length, 3);
      expect(state.bonusSlotsState.slots[1], isEmpty);
    });

    test('closed bonus slot use returns typed failure', () {
      final state = TriPeaksState.newGame(seed: 10);
      final result = tryReduceTriPeaks(state, const UseBonusSlotAction(2));

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, TriPeaksErrorCode.bonusSlotClosed);
    });

    test('actionable bonus slot indices match use-slot acceptance predicate',
        () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
          spawnOnOpenSlot2AtStreak: 3,
          spawnOnOpenSlot3AtStreak: 6,
        ),
      );

      expect(state.actionableBonusSlotIndices, equals(<int>[1]));
      final fromState = state.actionableBonusSlotIndices;
      expect(
        () => fromState.add(2),
        throwsUnsupportedError,
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
      expect(state.actionableBonusSlotIndices, equals(<int>[1, 2]));

      state = reduceTriPeaks(state, const RemoveTableauCardAction(21), tick: 4);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(22), tick: 5);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(23), tick: 6);
      expect(state.actionableBonusSlotIndices, equals(<int>[1, 2, 3]));

      for (var slot = 1; slot <= state.bonusSlotsConfig.maxSlots; slot++) {
        final expected = state.canUseBonusSlot(slot);
        final actual = state.actionableBonusSlotIndices.contains(slot);
        expect(actual, expected);
      }
    });

    test(
      'determinism: same seed+actions => same bonus slot open/close sequence',
      () {
        final actions = <TriPeaksAction>[
          const RemoveTableauCardAction(18),
          const RemoveTableauCardAction(19),
          const RemoveTableauCardAction(20),
          const DrawFromStockAction(),
          const RemoveTableauCardAction(21),
        ];
        var a = TriPeaksState.newGame(
          deck: buildStreakUnlockDeck(),
          streakConfig: const StreakConfig(
            resetOnDraw: true,
            resetOnInvalidAction: true,
          ),
        );
        var b = TriPeaksState.newGame(
          deck: buildStreakUnlockDeck(),
          streakConfig: const StreakConfig(
            resetOnDraw: true,
            resetOnInvalidAction: true,
          ),
        );
        final seqA = <int>[a.bonusSlotsState.openSlotsCount];
        final seqB = <int>[b.bonusSlotsState.openSlotsCount];
        for (final action in actions) {
          a = tryReduceTriPeaks(a, action).state;
          b = tryReduceTriPeaks(b, action).state;
          seqA.add(a.bonusSlotsState.openSlotsCount);
          seqB.add(b.bonusSlotsState.openSlotsCount);
        }

        expect(seqA, equals(seqB));
      },
    );

    test('draw always targets slot1 and remove can target explicit slot piles',
        () {
      var state = TriPeaksState.newGame(
        deck: buildBonusSlotTargetDeck(),
        streakConfig: const StreakConfig(resetOnDraw: false),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
          closeOnDraw: false,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      expect(state.bonusSlotsState.openSlotsCount, 2);

      final slot1Before = state.bonusSlotsState.slots[0].last;
      final drawToClosed = tryReduceTriPeaks(
        state,
        const DrawFromStockAction(targetSlot: 2),
      );
      expect(drawToClosed.isSuccess, isFalse);
      expect(drawToClosed.error?.code, TriPeaksErrorCode.invalidBonusSlotIndex);

      state = reduceTriPeaks(state, const DrawFromStockAction());
      expect(state.bonusSlotsState.slots[0].last, isNot(slot1Before));

      final rightSlot = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(21, targetSlot: 2),
      );
      expect(rightSlot.isSuccess, isTrue);
      expect(rightSlot.state.removed[21], isTrue);
      expect(rightSlot.state.bonusSlotsState.slots[1].length, 1);
    });

    test('undo restores bonus slot piles', () {
      var state = TriPeaksState.newGame(
        deck: buildBonusSlotTargetDeck(),
        undoConfig: const UndoConfig(maxSteps: 10),
        streakConfig: const StreakConfig(resetOnDraw: false),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
          closeOnDraw: false,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      state = reduceTriPeaks(state, const DrawFromStockAction());
      final beforeTake = state.bonusSlotsState.slots[1].length;

      state = reduceTriPeaks(
        state,
        const RemoveTableauCardAction(21, targetSlot: 2),
      );
      expect(state.bonusSlotsState.slots[1].length, beforeTake);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.removed[21], isFalse);
      expect(state.bonusSlotsState.slots[1].length, beforeTake);
    });

    test('stockTopCard draw close merges spawned slot card and undo restores',
        () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        undoConfig: const UndoConfig(maxSteps: 10),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
          closeOnDraw: true,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      final beforeSpawn = state;
      final spawnedCard = state.stock.first;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
      expect(state.bonusSlotsState.slots[1].single, spawnedCard);

      state = reduceTriPeaks(state, const DrawFromStockAction(), tick: 4);
      expect(state.bonusSlotsState.openSlotsCount, 1);
      expect(state.bonusSlotsState.slots[1], isEmpty);
      expect(state.bonusSlotsState.slots[0].contains(spawnedCard), isTrue);

      state = reduceTriPeaks(state, const UndoAction(), tick: 5);
      expect(state.bonusSlotsState.slots[1].single, spawnedCard);
      expect(state.stockCount, beforeSpawn.stockCount - 1);

      state = reduceTriPeaks(state, const UndoAction(), tick: 6);
      expect(state.stock, equals(beforeSpawn.stock));
      expect(
        state.bonusSlotsState.slots,
        equals(beforeSpawn.bonusSlotsState.slots),
      );
      expect(
        state.bonusSlotsState.openSlotsCount,
        beforeSpawn.bonusSlotsState.openSlotsCount,
      );
    });
  });
}
