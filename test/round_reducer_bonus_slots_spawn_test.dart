import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - bonus slots spawn', () {
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
  });
}
