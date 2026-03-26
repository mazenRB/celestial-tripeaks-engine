import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - bonus slots', () {
    test('bonus slots unlock at streak thresholds 2->1, 3->2, 6->3', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.joker,
          spawnOnOpenSlot2AtStreak: 3,
          spawnOnOpenSlot3AtStreak: 6,
        ),
      );
      expect(state.bonusSlotsState.openSlotsCount, 1);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      expect(state.streakState.currentStreak, 2);
      expect(state.bonusSlotsState.openSlotsCount, 1);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      expect(state.streakState.currentStreak, 3);
      expect(state.bonusSlotsState.openSlotsCount, 2);
      expect(state.bonusSlotsState.slots[1].single.isJoker, isTrue);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(21));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(22));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(23));
      expect(state.streakState.currentStreak, 6);
      expect(state.bonusSlotsState.openSlotsCount, 3);
      expect(state.bonusSlotsState.slots[2].single.isJoker, isTrue);
    });

    test('tierFixedRank spawns low-tier anchor after low-tier streak unlock',
        () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          lowTierAnchorRank: Rank.six,
          highTierAnchorRank: Rank.queen,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));

      final slot2Top = state.bonusSlotsState.slots[1].single;
      expect(slot2Top.isAnchor, isTrue);
      expect(slot2Top.rank, Rank.six);
    });

    test('tierFixedRank spawns high-tier anchor after high-tier streak unlock',
        () {
      var state = TriPeaksState.newGame(
        deck: buildHighTierUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          lowTierAnchorRank: Rank.six,
          highTierAnchorRank: Rank.queen,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));

      final slot2Top = state.bonusSlotsState.slots[1].single;
      expect(slot2Top.isAnchor, isTrue);
      expect(slot2Top.rank, Rank.queen);
    });

    test('tierRandomRank spawns low-tier rank from 2..10 domain', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));

      final slot2Top = state.bonusSlotsState.slots[1].single;
      expect(slot2Top.isAnchor, isTrue);
      final rank = slot2Top.rank;
      expect(rank.value >= 2 && rank.value <= 10, isTrue);
    });

    test('tierRandomRank spawns high-tier rank from A/J/Q/K domain', () {
      var state = TriPeaksState.newGame(
        deck: buildHighTierUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));

      final slot2Top = state.bonusSlotsState.slots[1].single;
      expect(slot2Top.isAnchor, isTrue);
      expect(
        <Rank>{Rank.ace, Rank.jack, Rank.queen, Rank.king}.contains(
          slot2Top.rank,
        ),
        isTrue,
      );
    });

    test('tierRandomRank is deterministic for same seed and action sequence',
        () {
      TriPeaksState run(int seed) {
        var state = TriPeaksState.newGame(
          seed: seed,
          deck: buildStreakUnlockDeck(),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
          ),
        );
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(21), tick: 4);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(22), tick: 5);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(23), tick: 6);
        return state;
      }

      final a = run(77);
      final b = run(77);
      expect(
        a.bonusSlotsState.slots[1].single.rank,
        b.bonusSlotsState.slots[1].single.rank,
      );
      expect(
        a.bonusSlotsState.slots[2].single.rank,
        b.bonusSlotsState.slots[2].single.rank,
      );
      expect(a.bonusAnchorSpawnNonce, b.bonusAnchorSpawnNonce);
    });

    test('tierRandomRank varies across seeds while remaining deterministic',
        () {
      final seen = <Rank>{};
      for (var seed = 1; seed <= 12; seed++) {
        var state = TriPeaksState.newGame(
          seed: seed,
          deck: buildStreakUnlockDeck(),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
          ),
        );
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
        state =
            reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
        seen.add(state.bonusSlotsState.slots[1].single.rank);
      }
      expect(seen.length, greaterThan(1));
    });

    test('tierRandomRank undo restores nonce and re-apply gives same rank', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        undoConfig: const UndoConfig(maxSteps: 5),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);

      final beforeSpawnNonce = state.bonusAnchorSpawnNonce;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
      final firstRank = state.bonusSlotsState.slots[1].single.rank;
      final afterSpawnNonce = state.bonusAnchorSpawnNonce;
      expect(afterSpawnNonce, beforeSpawnNonce + 1);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.bonusAnchorSpawnNonce, beforeSpawnNonce);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 4);
      expect(state.bonusSlotsState.slots[1].single.rank, firstRank);
      expect(state.bonusAnchorSpawnNonce, afterSpawnNonce);
    });

    test('tierRandomRank uses canonical 1-based slot index in mixing', () {
      var state = TriPeaksState.newGame(
        seed: 17,
        deck: buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      final nonceBeforeSpawn = state.bonusAnchorSpawnNonce;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);

      final expectedRank = expectedTierRandomRank(
        roundSeed: state.roundSeed,
        spawnNonce: nonceBeforeSpawn,
        slotIndex: 2,
        tier: BonusSlotAnchorTier.low,
      );
      expect(state.bonusSlotsState.slots[1].single.rank, expectedRank);
    });

    test('stockTopCard opens slots 2 and 3 by consuming stock in order', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          pointsDrawFromStock: 1000,
        ),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
          spawnOnOpenSlot2AtStreak: 3,
          spawnOnOpenSlot3AtStreak: 6,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);

      final expectedSlot2Card = state.stock.first;
      final stockBeforeSlot2 = state.stockCount;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
      expect(state.bonusSlotsState.openSlotsCount, 2);
      expect(state.bonusSlotsState.slots[1].single, expectedSlot2Card);
      expect(state.bonusSlotsState.slots[1].single.isJoker, isFalse);
      expect(state.bonusSlotsState.slots[1].single.isAnchor, isFalse);
      expect(state.stockCount, stockBeforeSlot2 - 1);
      expect(state.scoreState.lastBreakdown.drawPoints, 0);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(21), tick: 4);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(22), tick: 5);
      final expectedSlot3Card = state.stock.first;
      final stockBeforeSlot3 = state.stockCount;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(23), tick: 6);
      expect(state.bonusSlotsState.openSlotsCount, 3);
      expect(state.bonusSlotsState.slots[2].single, expectedSlot3Card);
      expect(state.stockCount, stockBeforeSlot3 - 1);
    });

    test('stockTopCard leaves slot closed when stock is empty', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        roundRulesConfig: const RoundRulesConfig(
          startStockSize: 0,
          stockDecreaseEveryRounds: 1,
          minStockSize: 0,
        ),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
          spawnOnOpenSlot2AtStreak: 3,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);

      expect(state.stockCount, 0);
      expect(state.bonusSlotsState.openSlotsCount, 1);
      expect(state.bonusSlotsState.slots[1], isEmpty);
      expect(state.actionableBonusSlotIndices, equals(<int>[1]));
    });

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
          const RemoveTableauCardAction(21), // likely invalid after draw
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
