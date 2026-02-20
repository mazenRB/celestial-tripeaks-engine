import 'dart:convert';
import 'dart:io';

import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TriPeaks reducer', () {
    test('starts with bottom row exposed', () {
      final state = TriPeaksState.newGame(seed: 42);

      expect(
        state.exposedTableauIndices,
        equals(List<int>.generate(10, (i) => 18 + i)),
      );
    });

    test('removes an exposed adjacent card to waste', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          18: const Card(Rank.six, Suit.clubs),
        },
        waste: const Card(Rank.seven, Suit.hearts),
      );
      final state = TriPeaksState.newGame(deck: deck);

      final next = reduceTriPeaks(state, const RemoveTableauCardAction(18));

      expect(next.tableauSnapshot[18], isNull);
      expect(next.wasteTop, const Card(Rank.six, Suit.clubs));
      expect(state.tableauSnapshot[18], isNotNull);
    });

    test('cannot remove non-exposed card even if rank is adjacent', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          9: const Card(Rank.six, Suit.clubs),
        },
        waste: const Card(Rank.seven, Suit.hearts),
      );
      final state = TriPeaksState.newGame(deck: deck);

      expect(state.isExposed(9), isFalse);
      expect(state.canRemoveTableau(9), isFalse);
      expect(
        () => reduceTriPeaks(state, const RemoveTableauCardAction(9)),
        throwsStateError,
      );
    });

    test('ace and king are not adjacent when wrap is disabled', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          18: const Card(Rank.ace, Suit.spades),
        },
        waste: const Card(Rank.king, Suit.hearts),
      );
      final state = TriPeaksState.newGame(
        deck: deck,
        roundRulesConfig: const RoundRulesConfig(aceKingWrapAround: false),
      );

      expect(state.canRemoveTableau(18), isFalse);
    });

    test('ace and king can be adjacent when wrap is enabled', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          18: const Card(Rank.ace, Suit.spades),
        },
        waste: const Card(Rank.king, Suit.hearts),
      );
      final state = TriPeaksState.newGame(
        deck: deck,
        roundRulesConfig: const RoundRulesConfig(aceKingWrapAround: true),
      );

      expect(state.canRemoveTableau(18), isTrue);
    });

    test('draws cards from stock to waste', () {
      final state = TriPeaksState.newGame(seed: 7);

      final next = reduceTriPeaks(state, const DrawFromStockAction());

      expect(next.stockCount, state.stockCount - 1);
      expect(next.wasteCount, state.wasteCount + 1);
      expect(state.stockCount, greaterThan(next.stockCount));
    });

    test('default scoring: tableau +5, draw +0, invalid +0', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          18: const Card(Rank.six, Suit.clubs),
        },
        waste: const Card(Rank.seven, Suit.hearts),
      );
      var state = TriPeaksState.newGame(deck: deck);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      expect(state.scoreState.totalScore, 5);
      expect(state.scoreState.lastDelta, 5);
      expect(state.scoreState.movesCount, 1);

      state = reduceTriPeaks(state, const DrawFromStockAction());
      expect(state.scoreState.totalScore, 5);
      expect(state.scoreState.lastDelta, 0);
      expect(state.scoreState.movesCount, 2);

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );
      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, 0);
      expect(invalid.state.scoreState.totalScore, 5);
      expect(invalid.state.scoreState.lastDelta, 0);
      expect(invalid.state.scoreState.movesCount, 3);
    });

    test('custom scoring: invalid penalty can be negative', () {
      final state = TriPeaksState.newGame(
        seed: 21,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, -3);
      expect(invalid.state.scoreState.totalScore, -3);
      expect(invalid.state.scoreState.lastDelta, -3);
      expect(invalid.state.scoreState.movesCount, 1);
    });

    test('determinism: same seed + actions + config => same score', () {
      const config = ScoreConfig(
        pointsTableauToWaste: 7,
        pointsDrawFromStock: 2,
        penaltyInvalidAction: -3,
      );
      final stateA = TriPeaksState.newGame(seed: 50, scoreConfig: config);
      final stateB = TriPeaksState.newGame(seed: 50, scoreConfig: config);
      final actions = <TriPeaksAction>[
        const DrawFromStockAction(),
        const DrawFromStockAction(),
        const RemoveTableauCardAction(99),
        const DrawFromStockAction(),
      ];

      final finalA = _applyTryActions(stateA, actions);
      final finalB = _applyTryActions(stateB, actions);

      expect(finalA.scoreState.totalScore, finalB.scoreState.totalScore);
      expect(finalA.scoreState.movesCount, finalB.scoreState.movesCount);
      expect(finalA.scoreState.lastDelta, finalB.scoreState.lastDelta);
    });

    test('undo enabled with maxSteps=3 reverts up to 3 and trims oldest', () {
      var state = TriPeaksState.newGame(
        seed: 5,
        undoConfig: const UndoConfig(maxSteps: 3),
      );

      state = reduceTriPeaks(state, const DrawFromStockAction());
      state = reduceTriPeaks(state, const DrawFromStockAction());
      state = reduceTriPeaks(state, const DrawFromStockAction());
      state = reduceTriPeaks(state, const DrawFromStockAction());

      expect(state.undoStepsAvailable, 3);
      expect(state.stockCount, 19);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 20);
      expect(state.undoStepsAvailable, 2);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 21);
      expect(state.undoStepsAvailable, 1);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 22);
      expect(state.undoStepsAvailable, 0);

      final noUndo = tryReduceTriPeaks(state, const UndoAction());
      expect(noUndo.isSuccess, isFalse);
      expect(noUndo.error?.code, TriPeaksErrorCode.nothingToUndo);
      expect(noUndo.state.stockCount, 22);
      expect(noUndo.state.undoStepsAvailable, 0);
    });

    test('undo disabled returns undoDisabled and does not change state', () {
      var state = TriPeaksState.newGame(
        seed: 6,
        undoConfig: const UndoConfig(enabled: false),
      );
      state = reduceTriPeaks(state, const DrawFromStockAction());
      expect(state.undoStepsAvailable, 0);

      final result = tryReduceTriPeaks(state, const UndoAction());

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, TriPeaksErrorCode.undoDisabled);
      expect(result.scoreDelta, 0);
      expect(result.state, same(state));
      expect(result.state.undoStepsAvailable, 0);
    });

    test('invalid actions do not create undo history in any mode', () {
      final enabledState = TriPeaksState.newGame(
        seed: 7,
        undoConfig: const UndoConfig(enabled: true, maxSteps: 3),
      );
      final enabledResult = tryReduceTriPeaks(
        enabledState,
        const RemoveTableauCardAction(99),
      );
      expect(enabledResult.isSuccess, isFalse);
      expect(enabledResult.state.undoStepsAvailable, 0);

      final disabledState = TriPeaksState.newGame(
        seed: 7,
        undoConfig: const UndoConfig(enabled: false, maxSteps: 3),
      );
      final disabledResult = tryReduceTriPeaks(
        disabledState,
        const RemoveTableauCardAction(99),
      );
      expect(disabledResult.isSuccess, isFalse);
      expect(disabledResult.state.undoStepsAvailable, 0);
    });

    test(
      'determinism: same seed + action sequence + undo config => same state',
      () {
        final initialA = TriPeaksState.newGame(
          seed: 99,
          undoConfig: const UndoConfig(maxSteps: 4),
        );
        final initialB = TriPeaksState.newGame(
          seed: 99,
          undoConfig: const UndoConfig(maxSteps: 4),
        );
        final actions = <TriPeaksAction>[
          const DrawFromStockAction(),
          const DrawFromStockAction(),
          const UndoAction(),
          const DrawFromStockAction(),
          const RemoveTableauCardAction(99), // invalid
        ];

        final finalA = _applyTryActions(initialA, actions);
        final finalB = _applyTryActions(initialB, actions);

        expect(finalA.stock, equals(finalB.stock));
        expect(finalA.waste, equals(finalB.waste));
        expect(finalA.removed, equals(finalB.removed));
        expect(finalA.scoreState.totalScore, finalB.scoreState.totalScore);
        expect(finalA.undoStepsAvailable, finalB.undoStepsAvailable);
      },
    );

    test('consecutive valid tableau moves increase streak', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs),
          Card(Rank.five, Suit.clubs),
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.eight, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      var state = TriPeaksState.newGame(deck: deck);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      expect(state.streakState.currentStreak, 1);
      expect(state.streakState.bestStreak, 1);
      expect(state.streakState.lastActionTick, 1);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      expect(state.streakState.currentStreak, 2);
      expect(state.streakState.bestStreak, 2);
      expect(state.streakState.lastActionTick, 2);
    });

    test('draw resets streak when configured', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs),
          Card(Rank.five, Suit.clubs),
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.eight, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      var state = TriPeaksState.newGame(
        deck: deck,
        streakConfig: const StreakConfig(resetOnDraw: true),
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      expect(state.streakState.currentStreak, 2);

      state = reduceTriPeaks(state, const DrawFromStockAction(), tick: 3);
      expect(state.streakState.currentStreak, 0);
      expect(state.streakState.bestStreak, 2);
      expect(state.streakState.lastActionTick, 2);
    });

    test('gap larger than maxGapTicks resets streak', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs),
          Card(Rank.five, Suit.clubs),
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.eight, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      var state = TriPeaksState.newGame(
        deck: deck,
        streakConfig: const StreakConfig(maxGapTicks: 2),
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      expect(state.streakState.currentStreak, 1);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 5);
      expect(state.streakState.currentStreak, 1);
      expect(state.streakState.bestStreak, 1);
      expect(state.streakState.lastActionTick, 5);
    });

    test('undo restores streak and lastActionTick', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs),
          Card(Rank.five, Suit.clubs),
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.eight, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      var state = TriPeaksState.newGame(
        deck: deck,
        undoConfig: const UndoConfig(enabled: true, maxSteps: 5),
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      expect(state.streakState.currentStreak, 2);
      expect(state.streakState.lastActionTick, 2);

      state = reduceTriPeaks(state, const UndoAction(), tick: 3);
      expect(state.streakState.currentStreak, 1);
      expect(state.streakState.bestStreak, 1);
      expect(state.streakState.lastActionTick, 1);
    });

    test('stale strike expiry token is ignored deterministically', () {
      var state = TriPeaksState.newGame(deck: _buildStreakUnlockDeck());
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      final staleToken = state.strikeTimerState.deadlineToken;

      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);
      final before = state.toMap();

      final result = tryReduceTriPeaks(
        state,
        StrikeTimerExpiredAction(deadlineToken: staleToken),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.error?.code,
        TriPeaksErrorCode.staleStrikeTimerExpiry,
      );
      expect(result.scoreDelta, 0);
      expect(result.state.toMap(), equals(before));
    });

    test('valid strike expiry ends streak and closes bonus slots', () {
      var state = TriPeaksState.newGame(deck: _buildStreakUnlockDeck());
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);

      expect(state.streakState.currentStreak, 3);
      expect(state.bonusSlotsState.openSlotsCount, 2);
      expect(state.strikeTimerState.isArmed, isTrue);

      state = reduceTriPeaks(
        state,
        StrikeTimerExpiredAction(
          deadlineToken: state.strikeTimerState.deadlineToken,
        ),
      );

      expect(state.streakState.currentStreak, 0);
      expect(state.bonusSlotsState.openSlotsCount, 1);
      expect(state.strikeTimerState.isArmed, isFalse);
    });

    test('streak advance resets strike deadline token', () {
      var state = TriPeaksState.newGame(deck: _buildStreakUnlockDeck());
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      final firstToken = state.strikeTimerState.deadlineToken;
      expect(state.strikeTimerState.isArmed, isTrue);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      final secondToken = state.strikeTimerState.deadlineToken;
      expect(secondToken, isNot(firstToken));

      final staleResult = tryReduceTriPeaks(
        state,
        StrikeTimerExpiredAction(deadlineToken: firstToken),
      );
      expect(staleResult.isSuccess, isFalse);
      expect(
        staleResult.error?.code,
        TriPeaksErrorCode.staleStrikeTimerExpiry,
      );
    });

    test('tryReduce returns typed error on invalid tableau index', () {
      final state = TriPeaksState.newGame(seed: 8);

      final result = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.error?.code,
        TriPeaksErrorCode.invalidTableauIndex,
      );
      expect(result.scoreDelta, 0);
      expect(result.state.scoreState.totalScore, 0);
      expect(result.state.scoreState.movesCount, 1);
      expect(result.state.scoreState.lastDelta, 0);
    });

    test('tryReduce returns typed error when stock is empty', () {
      var state = TriPeaksState.newGame(seed: 9);
      while (state.canDrawFromStock) {
        state = reduceTriPeaks(state, const DrawFromStockAction());
      }

      final result = tryReduceTriPeaks(state, const DrawFromStockAction());

      expect(result.isSuccess, isFalse);
      expect(
        result.error?.code,
        TriPeaksErrorCode.emptyStock,
      );
      expect(result.scoreDelta, 0);
      expect(result.state.scoreState.totalScore, state.scoreState.totalScore);
      expect(
        result.state.scoreState.movesCount,
        state.scoreState.movesCount + 1,
      );
      expect(result.state.scoreState.lastDelta, 0);
    });

    test('rejects invalid deck definitions', () {
      final invalidDeck = List<Card>.filled(
        52,
        const Card(Rank.ace, Suit.clubs),
      );

      expect(
        () => TriPeaksState.newGame(deck: invalidDeck),
        throwsArgumentError,
      );
    });

    test('uses deterministic default seed when no seed is provided', () {
      final stateA = TriPeaksState.newGame();
      final stateB = TriPeaksState.newGame();

      expect(stateA.tableau, equals(stateB.tableau));
      expect(stateA.waste, equals(stateB.waste));
      expect(stateA.stock, equals(stateB.stock));
    });

    test('clearing one peak awards peak bonus exactly once', () {
      var state = TriPeaksState.newGame(
        deck: _buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 50);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(22));
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 50);
    });

    test('clearing remaining peaks awards additional peak bonuses', () {
      var state = TriPeaksState.newGame(
        deck: _buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
      );

      for (final index in <int>[
        18, 19, 20, 21, 9, 10, 11, 3, 4, 0, // peak 0
        22, 23, 24, 12, 13, 14, 6, 5, 1, // peak 1
        25, 26, 27, 17, 16, 15, 8, 7, 2, // peak 2
      ]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }

      expect(state.clearedPeaksAwarded, equals(<int>{0, 1, 2}));
      expect(state.scoreState.totalScore, 150);
    });

    test('undo restores peak bonus score and awarded tracking', () {
      var state = TriPeaksState.newGame(
        deck: _buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
        undoConfig: const UndoConfig(enabled: true, maxSteps: 20),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.scoreState.totalScore, 50);
      expect(state.clearedPeaksAwarded, equals(<int>{0}));

      state = reduceTriPeaks(state, const UndoAction());

      expect(state.scoreState.totalScore, 0);
      expect(state.clearedPeaksAwarded, isEmpty);
      expect(state.removed[0], isFalse);
    });

    test('no peak bonus is awarded when pointsPeakCleared is zero', () {
      var state = TriPeaksState.newGame(
        deck: _buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 0,
        ),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 0);
    });

    test('bonus slots unlock at streak thresholds 2->1, 3->2, 6->3', () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildHighTierUnlockDeck(),
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

    test(
      'placing any tableau card onto joker slot is accepted and consumes joker',
      () {
        var state = TriPeaksState.newGame(
          deck: _buildJokerConsumeDeck(),
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
        deck: _buildJokerConsumeDeck(),
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
        deck: _buildJokerConsumeDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
          deck: _buildStreakUnlockDeck(),
          streakConfig: const StreakConfig(
            resetOnDraw: true,
            resetOnInvalidAction: true,
          ),
        );
        var b = TriPeaksState.newGame(
          deck: _buildStreakUnlockDeck(),
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
        deck: _buildBonusSlotTargetDeck(),
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
        deck: _buildBonusSlotTargetDeck(),
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
  });

  group('TriPeaks session reducer', () {
    test('supports 3, 6, and 10 rounds via ruleset', () {
      final three = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 1,
      );
      final six = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.sixRounds,
        seed: 1,
      );
      final ten = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.tenRounds,
        seed: 1,
      );

      expect(three.ruleset.roundsPerGame, 3);
      expect(six.ruleset.roundsPerGame, 6);
      expect(ten.ruleset.roundsPerGame, 10);
    });

    test('uses deterministic default seed for sessions', () {
      final sessionA = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );
      final sessionB = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );

      expect(
          sessionA.currentRound.tableau, equals(sessionB.currentRound.tableau));
      expect(sessionA.currentRound.waste, equals(sessionB.currentRound.waste));
      expect(sessionA.currentRound.stock, equals(sessionB.currentRound.stock));
    });

    test('can advance to next round after finishing current round', () {
      final round1Deck = _buildAlwaysLostDeck(
        waste: const Card(Rank.ace, Suit.clubs),
      );
      final round2Deck = _buildAlwaysLostDeck(
        waste: const Card(Rank.king, Suit.diamonds),
      );
      final round3Deck = _buildAlwaysLostDeck(
        waste: const Card(Rank.queen, Suit.hearts),
      );

      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: <List<Card>>[
          round1Deck,
          round2Deck,
          round3Deck,
        ],
      );

      // Exhaust stock to force round 1 loss.
      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.currentRound.isLost, isTrue);
      expect(session.roundsCompleted, 1);
      expect(session.roundsLost, 1);
      expect(session.roundResults.last.outcome, RoundOutcome.lost);

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRoundNumber, 2);
      expect(session.roundsCompleted, 1);
    });

    test('cannot start next round before current round finishes', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 2,
      );

      final result = tryReduceTriPeaksSession(
        session,
        const StartNextRoundAction(),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.sessionError?.code,
        TriPeaksSessionErrorCode.roundNotFinished,
      );
    });

    test('session uses configured invalid-action penalty', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 13,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );

      final result = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(RemoveTableauCardAction(99)),
      );

      expect(result.isSuccess, isFalse);
      expect(result.roundError?.code, TriPeaksErrorCode.invalidTableauIndex);
      expect(result.state.currentRound.scoreState.totalScore, -3);
      expect(result.state.currentRound.scoreState.lastDelta, -3);
      expect(result.state.currentRound.scoreState.movesCount, 1);
    });

    test('abort active round records aborted result and advances', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 17,
      );
      final expectedRoundTwo = TriPeaksState.newGame(seed: 18);

      final next = reduceTriPeaksSession(
        session,
        const AbortRoundAction(reason: AbortReason.userQuit),
      );

      expect(next.currentRoundNumber, 2);
      expect(next.roundsCompleted, 1);
      expect(next.roundsAborted, 1);
      expect(next.roundsWon, 0);
      expect(next.roundsLost, 0);
      expect(next.roundResults, hasLength(1));
      expect(next.roundResults.single.outcome, RoundOutcome.aborted);
      expect(next.roundResults.single.abortReason, AbortReason.userQuit);
      expect(next.currentRound.tableau, equals(expectedRoundTwo.tableau));
      expect(next.currentRound.waste, equals(expectedRoundTwo.waste));
      expect(next.currentRound.stock, equals(expectedRoundTwo.stock));
    });

    test('abort on last round finishes session', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 30,
      );

      final afterFirstAbort = reduceTriPeaksSession(
        session,
        const AbortRoundAction(),
      );
      final afterSecondAbort = reduceTriPeaksSession(
        afterFirstAbort,
        const AbortRoundAction(),
      );
      final afterThirdAbort = reduceTriPeaksSession(
        afterSecondAbort,
        const AbortRoundAction(reason: AbortReason.disconnect),
      );

      expect(afterThirdAbort.isSessionFinished, isTrue);
      expect(afterThirdAbort.roundsCompleted, 3);
      expect(afterThirdAbort.roundsAborted, 3);
      expect(afterThirdAbort.roundResults, hasLength(3));
      expect(afterThirdAbort.roundResults.last.outcome, RoundOutcome.aborted);
      expect(
        afterThirdAbort.roundResults.last.abortReason,
        AbortReason.disconnect,
      );
    });

    test('abort when session finished returns typed failure', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 77,
      );
      final done = reduceTriPeaksSession(
        reduceTriPeaksSession(
          reduceTriPeaksSession(session, const AbortRoundAction()),
          const AbortRoundAction(),
        ),
        const AbortRoundAction(),
      );
      expect(done.isSessionFinished, isTrue);

      final result = tryReduceTriPeaksSession(done, const AbortRoundAction());

      expect(result.isSuccess, isFalse);
      expect(
        result.sessionError?.code,
        TriPeaksSessionErrorCode.gameAlreadyFinished,
      );
      expect(result.state, same(done));
    });
  });

  group('Hint queries', () {
    test('playable moves and deterministic hint when moves exist', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs), // 18 playable
          Card(Rank.eight, Suit.clubs), // 19 playable
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.five, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      final state = TriPeaksState.newGame(deck: deck);
      const rules = RoundRulesConfig(aceKingWrapAround: false);

      final playable = getPlayableMoves(state, rules);
      final hint = getHint(state, rules, const HintConfig());

      expect(playable, equals(<int>[18, 19]));
      expect(hint.isSuccess, isTrue);
      expect(hint.moveIndex, 18);
    });

    test('no playable moves returns typed noHintAvailable', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.five, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
          Card(Rank.jack, Suit.diamonds),
          Card(Rank.king, Suit.diamonds),
        ],
      );
      final state = TriPeaksState.newGame(deck: deck);

      final playable = getPlayableMoves(
        state,
        const RoundRulesConfig(aceKingWrapAround: false),
      );
      final hint = getHint(
        state,
        const RoundRulesConfig(aceKingWrapAround: false),
        const HintConfig(),
      );

      expect(playable, isEmpty);
      expect(hint.isSuccess, isFalse);
      expect(hint.error?.code, HintErrorCode.noHintAvailable);
    });

    test('hint output is stable across repeated calls', () {
      final deck = _buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs),
          Card(Rank.eight, Suit.clubs),
          Card(Rank.two, Suit.clubs),
          Card(Rank.four, Suit.clubs),
          Card(Rank.ten, Suit.clubs),
          Card(Rank.queen, Suit.clubs),
          Card(Rank.ace, Suit.clubs),
          Card(Rank.three, Suit.diamonds),
          Card(Rank.five, Suit.diamonds),
          Card(Rank.nine, Suit.diamonds),
        ],
      );
      final state = TriPeaksState.newGame(deck: deck);
      const rules = RoundRulesConfig(aceKingWrapAround: false);
      const hintConfig = HintConfig();

      final hintA = getHint(state, rules, hintConfig);
      final hintB = getHint(state, rules, hintConfig);

      expect(hintA.isSuccess, isTrue);
      expect(hintA.moveIndex, hintB.moveIndex);
    });

    test('hint respects enabled flag', () {
      final state = TriPeaksState.newGame(seed: 4);

      final hint = getHint(
        state,
        const RoundRulesConfig(),
        const HintConfig(enabled: false),
      );

      expect(hint.isSuccess, isFalse);
      expect(hint.error?.code, HintErrorCode.hintDisabled);
    });
  });

  group('Match scoring layer', () {
    test('round score is unaffected by multiplayer bonuses', () {
      final deck = _buildDeck(
        tableauOverrides: <int, Card>{
          18: const Card(Rank.six, Suit.clubs),
        },
        waste: const Card(Rank.seven, Suit.hearts),
      );
      final roundState = reduceTriPeaks(
        TriPeaksState.newGame(deck: deck),
        const RemoveTableauCardAction(18),
      );
      final beforeRoundScore = roundState.scoreState.totalScore;

      var match = MatchScoreState(
        config: const MatchScoreConfig(firstFinishBonus: 10),
      );
      match = reduceMatchScore(
        match,
        RoundScoreAggregated(
          playerId: 'p1',
          roundScore: roundState.scoreState.totalScore,
        ),
      );
      match = reduceMatchScore(
        match,
        const FirstFinishBonusApplied(playerId: 'p1'),
      );

      expect(roundState.scoreState.totalScore, beforeRoundScore);
      expect(roundState.scoreState.totalScore, 5);
      expect(match.totalFor('p1'), 15);
    });

    test('applies first-finish bonus to match score', () {
      var match = MatchScoreState(
        config: const MatchScoreConfig(firstFinishBonus: 12),
      );

      match = reduceMatchScore(
        match,
        const RoundScoreAggregated(playerId: 'p1', roundScore: 9),
      );
      match = reduceMatchScore(
        match,
        const FirstFinishBonusApplied(playerId: 'p1'),
      );

      expect(match.totalFor('p1'), 21);
      expect(match.firstFinishAwardedTo, 'p1');
    });

    test('determinism: identical event sequence gives identical totals', () {
      final initialA = MatchScoreState(
        config: const MatchScoreConfig(
          firstFinishBonus: 15,
          rankingAdjustments: <int, int>{1: 7, 2: 2},
        ),
      );
      final initialB = MatchScoreState(
        config: const MatchScoreConfig(
          firstFinishBonus: 15,
          rankingAdjustments: <int, int>{1: 7, 2: 2},
        ),
      );
      final events = <MatchScoreEvent>[
        const RoundScoreAggregated(playerId: 'p1', roundScore: 11),
        const RoundScoreAggregated(playerId: 'p2', roundScore: 8),
        const FirstFinishBonusApplied(playerId: 'p1'),
        const RankingAdjustmentApplied(playerId: 'p1', rank: 1),
        const RankingAdjustmentApplied(playerId: 'p2', rank: 2),
      ];

      final finalA = _applyMatchEvents(initialA, events);
      final finalB = _applyMatchEvents(initialB, events);

      expect(finalA.totalScoresByPlayer, equals(finalB.totalScoresByPlayer));
      expect(finalA.processedEventsCount, finalB.processedEventsCount);
      expect(finalA.firstFinishAwardedTo, finalB.firstFinishAwardedTo);
    });
  });

  group('TriPeaksGame wrapper', () {
    test('updates state via dispatch', () {
      final game = TriPeaksGame.newGame(seed: 3);
      final before = game.state;

      game.dispatch(const PlayRoundAction(DrawFromStockAction()));

      expect(game.state, isNot(same(before)));
      expect(game.state.stockCount, before.stockCount - 1);
    });
  });

  group('Daily challenge', () {
    test('same date + same config gives same seed and same initial deal', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const date = DateOnly(2026, 2, 20);

      final seedA = dailySeedForDate(date, config);
      final seedB = dailySeedForDate(date, config);
      final gameA = newDailyGame(date, config);
      final gameB = newDailyGame(date, config);

      expect(seedA, seedB);
      expect(gameA.tableau, equals(gameB.tableau));
      expect(gameA.waste, equals(gameB.waste));
      expect(gameA.stock, equals(gameB.stock));
    });

    test('adjacent dates produce different seeds', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const dayA = DateOnly(2026, 2, 20);
      const dayB = DateOnly(2026, 2, 21);

      final seedA = dailySeedForDate(dayA, config);
      final seedB = dailySeedForDate(dayB, config);

      expect(seedA, isNot(seedB));
    });

    test('namespaceId and modeId influence daily seed', () {
      const date = DateOnly(2026, 2, 20);
      const base = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const otherNamespace = DailyChallengeConfig(
        namespaceId: 'staging',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const otherMode = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'hard',
        schemaVersion: 1,
      );

      final baseSeed = dailySeedForDate(date, base);
      final namespaceSeed = dailySeedForDate(date, otherNamespace);
      final modeSeed = dailySeedForDate(date, otherMode);

      expect(baseSeed, isNot(namespaceSeed));
      expect(baseSeed, isNot(modeSeed));
    });

    test('seed derivation uses provided date only (timezone-independent)', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
      );
      final fromUtc = DateOnly.fromDateTime(DateTime.utc(2026, 2, 20, 23, 59));
      const explicit = DateOnly(2026, 2, 20);

      final utcSeed = dailySeedForDate(fromUtc, config);
      final explicitSeed = dailySeedForDate(explicit, config);

      expect(utcSeed, explicitSeed);
    });
  });

  group('Replay', () {
    test('replayToState matches live state for same action sequence', () {
      final config = ScoreConfig(
        pointsTableauToWaste: 7,
        pointsDrawFromStock: 2,
        penaltyInvalidAction: -3,
      );
      var liveState = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 42,
        scoreConfig: config,
        undoConfig: const UndoConfig(maxSteps: 4),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
      );
      var replay = TriPeaksReplay.newSession(
        seed: 42,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: config,
        undoConfig: const UndoConfig(maxSteps: 4),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
      );
      final actions = <({TriPeaksSessionAction action, int? tick})>[
        (action: const PlayRoundAction(DrawFromStockAction()), tick: 1),
        (action: const PlayRoundAction(RemoveTableauCardAction(99)), tick: 2),
        (action: const PlayRoundAction(UndoAction()), tick: 3),
        (action: const AbortRoundAction(reason: AbortReason.userSkip), tick: 4),
      ];

      for (final item in actions) {
        final recorded = recordAction(
          replay,
          liveState,
          item.action,
          tick: item.tick,
        );
        replay = recorded.replay;
        liveState = recorded.state;
      }

      final rebuilt = replayToState(replay);

      expect(rebuilt.currentRoundNumber, liveState.currentRoundNumber);
      expect(rebuilt.roundsCompleted, liveState.roundsCompleted);
      expect(rebuilt.roundsWon, liveState.roundsWon);
      expect(rebuilt.roundsLost, liveState.roundsLost);
      expect(rebuilt.roundsAborted, liveState.roundsAborted);
      expect(
        rebuilt.roundResults.map((result) {
          return (
            result.roundNumber,
            result.outcome,
            result.abortReason,
          );
        }).toList(growable: false),
        equals(
          liveState.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
            );
          }).toList(growable: false),
        ),
      );
      expect(
          rebuilt.currentRound.tableau, equals(liveState.currentRound.tableau));
      expect(
          rebuilt.currentRound.removed, equals(liveState.currentRound.removed));
      expect(rebuilt.currentRound.waste, equals(liveState.currentRound.waste));
      expect(rebuilt.currentRound.stock, equals(liveState.currentRound.stock));
      expect(
        rebuilt.currentRound.scoreState.totalScore,
        liveState.currentRound.scoreState.totalScore,
      );
      expect(
        rebuilt.currentRound.streakState.currentStreak,
        liveState.currentRound.streakState.currentStreak,
      );
    });

    test('rejected attempts do not change replayed state', () {
      final state = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 33,
        undoConfig: const UndoConfig(enabled: false),
      );
      var replay = ReplaySession.newSession(
        seed: 33,
        ruleset: TriPeaksRuleset.threeRounds,
        undoConfig: const UndoConfig(enabled: false),
      );

      final rejected = tryReduceTriPeaksSession(
        state,
        const PlayRoundAction(UndoAction()),
      );
      replay = recordAttempt(
        replay,
        const PlayRoundAction(UndoAction()),
        rejected,
      );

      expect(replay.entries.single.accepted, isFalse);
      expect(
        replay.entries.single.failureReason,
        ReplayFailureReason.undoDisabled,
      );

      final rebuilt = replayToState(replay);
      expect(rebuilt.currentRound.tableau, equals(state.currentRound.tableau));
      expect(rebuilt.currentRound.removed, equals(state.currentRound.removed));
      expect(rebuilt.currentRound.waste, equals(state.currentRound.waste));
      expect(rebuilt.currentRound.stock, equals(state.currentRound.stock));
    });

    test('replay map round-trip preserves deterministic reconstruction', () {
      var state = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 11,
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          pointsDrawFromStock: 1,
          penaltyInvalidAction: -3,
        ),
      );
      var replay = TriPeaksReplay.newSession(
        seed: 11,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          pointsDrawFromStock: 1,
          penaltyInvalidAction: -3,
        ),
      );

      for (final action in <TriPeaksSessionAction>[
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(RemoveTableauCardAction(99)),
        const PlayRoundAction(UndoAction()),
      ]) {
        final recorded = recordAction(replay, state, action);
        replay = recorded.replay;
        state = recorded.state;
      }

      final encoded = jsonEncode(replay.toMap());
      final decodeResult = ReplaySession.tryFromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decodeResult.isSuccess, isTrue);
      final decoded = decodeResult.value!;

      final rebuiltOriginal = replayToState(replay);
      final rebuiltDecoded = replayToState(decoded);

      expect(
        rebuiltOriginal.currentRound.tableau,
        equals(rebuiltDecoded.currentRound.tableau),
      );
      expect(
        rebuiltOriginal.currentRound.removed,
        equals(rebuiltDecoded.currentRound.removed),
      );
      expect(
        rebuiltOriginal.currentRound.waste,
        equals(rebuiltDecoded.currentRound.waste),
      );
      expect(
        rebuiltOriginal.currentRound.stock,
        equals(rebuiltDecoded.currentRound.stock),
      );
      expect(
        rebuiltOriginal.currentRound.scoreState.totalScore,
        rebuiltDecoded.currentRound.scoreState.totalScore,
      );
      expect(
        rebuiltOriginal.roundResults.map((result) {
          return (
            result.roundNumber,
            result.outcome,
            result.abortReason,
          );
        }).toList(growable: false),
        equals(
          rebuiltDecoded.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
            );
          }).toList(growable: false),
        ),
      );
      expect(decoded.entries.length, replay.entries.length);
      expect(decoded.entries.first.accepted, replay.entries.first.accepted);
      expect(
          decoded.entries.first.action.kind, replay.entries.first.action.kind);
    });

    test(
      'tierFixedRank anchor behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 0,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
            lowTierAnchorRank: Rank.six,
            highTierAnchorRank: Rank.queen,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: 0,
          ruleset: TriPeaksRuleset.threeRounds,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
            lowTierAnchorRank: Rank.six,
            highTierAnchorRank: Rank.queen,
          ),
        );

        var guard = 0;
        while (liveState.currentRound.streakState.currentStreak < 3 &&
            guard < 64) {
          final moves =
              liveState.currentRound.availableMoves.removableTableauIndices;
          final action = moves.isNotEmpty
              ? PlayRoundAction(RemoveTableauCardAction(moves.first))
              : const PlayRoundAction(DrawFromStockAction());
          final recorded = recordAction(replay, liveState, action);
          replay = recorded.replay;
          liveState = recorded.state;
          guard++;
        }
        expect(liveState.currentRound.streakState.currentStreak,
            greaterThanOrEqualTo(3));

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.isAnchor,
          isTrue,
        );
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.rank,
          liveState.currentRound.bonusSlotsState.slots[1].single.rank,
        );
        expect(sessionFingerprint(rebuilt), sessionFingerprint(liveState));
      },
    );

    test('unsupported replay schema returns typed failure', () {
      final decode = ReplaySession.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 999,
          'engineVersion': 1,
          'seed': 0,
          'roundsPerGame': 3,
          'scoreConfig': <String, dynamic>{
            'pointsTableauToWaste': 5,
            'pointsDrawFromStock': 0,
            'penaltyInvalidAction': 0,
          },
          'roundRulesConfig': <String, dynamic>{'aceKingWrapAround': false},
          'undoConfig': <String, dynamic>{'enabled': true, 'maxSteps': 10},
          'streakConfig': <String, dynamic>{
            'enabled': true,
            'resetOnDraw': true,
            'resetOnInvalidAction': false,
          },
          'entries': <Map<String, dynamic>>[],
        },
      );

      expect(decode.isSuccess, isFalse);
      expect(
        decode.error?.code,
        DecodeFailureCode.unsupportedSchemaVersion,
      );
    });
  });

  group('Serialization', () {
    test('round state map round-trip preserves deep state', () {
      final original = TriPeaksState.newGame(
        seed: 5,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
        undoConfig: const UndoConfig(maxSteps: 4),
      );
      final progressed = _applyTryActions(
        original,
        const <TriPeaksAction>[
          DrawFromStockAction(),
          DrawFromStockAction(),
          RemoveTableauCardAction(99),
        ],
      );

      final decoded = TriPeaksState.tryFromMap(
        progressed.toMap(),
      );
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;

      expect(restored.tableau, equals(progressed.tableau));
      expect(restored.removed, equals(progressed.removed));
      expect(restored.waste, equals(progressed.waste));
      expect(restored.stock, equals(progressed.stock));
      expect(restored.scoreConfig.penaltyInvalidAction, -3);
      expect(restored.scoreState.totalScore, progressed.scoreState.totalScore);
      expect(
        restored.streakState.currentStreak,
        progressed.streakState.currentStreak,
      );
      expect(restored.undoStepsAvailable, progressed.undoStepsAvailable);
    });

    test('tierFixedRank config and anchor card round-trip via map', () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.high,
          lowTierAnchorRank: Rank.eight,
          highTierAnchorRank: Rank.king,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      final before = stateFingerprint(state);

      final decoded = TriPeaksState.tryFromMap(state.toMap());
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;

      expect(restored.bonusSlotsConfig.spawnPolicy,
          BonusSlotSpawnPolicy.tierFixedRank);
      expect(
        restored.bonusSlotsConfig.defaultAnchorTierWhenUnknown,
        BonusSlotAnchorTier.high,
      );
      expect(restored.bonusSlotsConfig.lowTierAnchorRank, Rank.eight);
      expect(restored.bonusSlotsConfig.highTierAnchorRank, Rank.king);
      expect(restored.bonusSlotsState.slots[1].single.isAnchor, isTrue);
      expect(stateFingerprint(restored), before);
    });

    test('session action map round-trip preserves action identity', () {
      final actions = <TriPeaksSessionAction>[
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(RemoveTableauCardAction(12)),
        const PlayRoundAction(UndoAction()),
        const PlayRoundAction(StrikeTimerExpiredAction(deadlineToken: 7)),
        const StartNextRoundAction(),
        const AbortRoundAction(reason: AbortReason.disconnect),
      ];

      for (final action in actions) {
        final map = sessionActionToMap(action);
        final decodedEnvelope = decodeActionEnvelope(map);
        expect(decodedEnvelope.isSuccess, isTrue);
        final decoded = decodedEnvelope.value!.sessionAction!;

        expect(map['type'], 'tripeaks_session_action');
        switch ((action, decoded)) {
          case (
              PlayRoundAction(action: DrawFromStockAction()),
              PlayRoundAction(action: DrawFromStockAction())
            ):
            break;
          case (
              PlayRoundAction(action: RemoveTableauCardAction(index: final a)),
              PlayRoundAction(action: RemoveTableauCardAction(index: final b))
            ):
            expect(a, b);
            break;
          case (
              PlayRoundAction(action: UndoAction()),
              PlayRoundAction(action: UndoAction())
            ):
            break;
          case (
              PlayRoundAction(
                action: StrikeTimerExpiredAction(deadlineToken: final a),
              ),
              PlayRoundAction(
                action: StrikeTimerExpiredAction(deadlineToken: final b),
              )
            ):
            expect(a, b);
            break;
          case (StartNextRoundAction(), StartNextRoundAction()):
            break;
          case (
              AbortRoundAction(reason: final a),
              AbortRoundAction(reason: final b)
            ):
            expect(a, b);
            break;
          default:
            fail('Decoded action did not match original.');
        }
      }
    });

    test('decodeStateEnvelope returns typed failure for unsupported version',
        () {
      final result = decodeStateEnvelope(
        <String, dynamic>{
          'schemaVersion': 999,
          'type': 'tripeaks_round_state',
        },
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.error?.code,
        DecodeFailureCode.unsupportedSchemaVersion,
      );
    });
  });

  group('Fingerprint', () {
    test('identical states produce identical fingerprint', () {
      final stateA = TriPeaksState.newGame(seed: 12);
      final stateB = TriPeaksState.newGame(seed: 12);

      expect(stateFingerprint(stateA), stateFingerprint(stateB));
    });

    test('small state change produces a different fingerprint', () {
      final state = TriPeaksState.newGame(seed: 12);
      final changed = reduceTriPeaks(state, const DrawFromStockAction());

      expect(stateFingerprint(state), isNot(stateFingerprint(changed)));
    });

    test('fingerprint is stable for fixed canonical state', () {
      final state = TriPeaksState.newGame(seed: 42);
      expect(stateFingerprint(state), '4416c38c');
    });
  });

  group('Save/Load', () {
    test('round save round-trip preserves state and fingerprint', () {
      final initial = TriPeaksState.newGame(
        seed: 17,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );
      final state = _applyTryActions(
        initial,
        const <TriPeaksAction>[
          DrawFromStockAction(),
          RemoveTableauCardAction(99),
          DrawFromStockAction(),
        ],
      );

      final save = encodeSaveRound(state, engineVersion: 1, savedAtSequence: 9);
      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isTrue);
      final value = decoded.value!;
      expect(value.savedAtSequence, 9);
      expect(value.engineVersion, 1);
      expect(value.fingerprint, stateFingerprint(state));
      expect(value.state.tableau, equals(state.tableau));
      expect(value.state.removed, equals(state.removed));
      expect(value.state.waste, equals(state.waste));
      expect(value.state.stock, equals(state.stock));
      expect(value.state.scoreState.totalScore, state.scoreState.totalScore);
    });

    test('corrupted round payload returns corruptSave failure', () {
      final state = TriPeaksState.newGame(seed: 17);
      final save = encodeSaveRound(state);
      final payload = save['payload'] as Map<String, dynamic>;
      final removed = (payload['removed'] as List<dynamic>).toList();
      removed[0] = !(removed[0] as bool);
      payload['removed'] = removed;

      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, SaveDecodeFailureCode.corruptSave);
    });

    test('unsupported save schemaVersion returns typed failure', () {
      final state = TriPeaksState.newGame(seed: 17);
      final save = encodeSaveRound(state);
      save['schemaVersion'] = 999;

      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, SaveDecodeFailureCode.unsupportedVersion);
    });
  });

  group('Deal policy', () {
    test('random mode returns deal on first attempt', () {
      final result = newGameWithDealPolicy(
        123,
        dealPolicy: const DealPolicyConfig(mode: DealPolicyMode.random),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state, isNotNull);
      expect(result.attemptCount, 1);
      expect(result.attemptSeed, 123);
    });

    test(
      'requireSolvable returns solvable deal or typed failure within maxAttempts',
      () {
        const policy = DealPolicyConfig(
          mode: DealPolicyMode.requireSolvable,
          maxAttempts: 5,
          solverNodeLimit: 50000,
        );
        final result = newGameWithDealPolicy(123, dealPolicy: policy);

        if (result.isSuccess) {
          expect(result.state, isNotNull);
          expect(isDealSolvable(result.state!), isTrue);
          expect(result.attemptCount!, inInclusiveRange(1, policy.maxAttempts));
        } else {
          expect(result.failure?.code, DealFailureCode.noSolvableDealFound);
        }
      },
    );

    test('same inputs produce same selected deal for requireSolvable', () {
      const policy = DealPolicyConfig(
        mode: DealPolicyMode.requireSolvable,
        maxAttempts: 20,
        attemptSeedStrategy: AttemptSeedStrategy.fnv1aMix,
        solverNodeLimit: 70000,
      );
      final a = newGameWithDealPolicy(777, dealPolicy: policy);
      final b = newGameWithDealPolicy(777, dealPolicy: policy);

      expect(a.isSuccess, b.isSuccess);
      if (!a.isSuccess) {
        expect(a.failure?.code, b.failure?.code);
        return;
      }
      expect(a.attemptSeed, b.attemptSeed);
      expect(a.attemptCount, b.attemptCount);
      expect(a.state!.tableau, equals(b.state!.tableau));
      expect(a.state!.waste, equals(b.state!.waste));
      expect(a.state!.stock, equals(b.state!.stock));
    });
  });

  group('Multiplayer match', () {
    MatchState buildInitialMatch() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'm1',
        matchSeed: 12345,
        maxPlayers: 4,
        ruleset: TriPeaksRuleset.threeRounds,
        dealPolicyConfig: const DealPolicyConfig(mode: DealPolicyMode.random),
      );
      return MatchState.newMatch(config: config);
    }

    test('players get identical initial deals with same matchSeed', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(
        match,
        const JoinMatchEvent(playerId: 'p1'),
      ).state;
      match = tryReduceMatch(
        match,
        const JoinMatchEvent(playerId: 'p2'),
      ).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final p1 = match.players.firstWhere((player) => player.playerId == 'p1');
      final p2 = match.players.firstWhere((player) => player.playerId == 'p2');

      expect(p1.session, isNotNull);
      expect(p2.session, isNotNull);
      expect(
        p1.session!.currentRound.tableau,
        equals(p2.session!.currentRound.tableau),
      );
      expect(p1.session!.currentRound.waste,
          equals(p2.session!.currentRound.waste));
      expect(p1.session!.currentRound.stock,
          equals(p2.session!.currentRound.stock));
    });

    test('submit action affects only submitting player state and replay', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p2')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final beforeP1 =
          match.players.firstWhere((player) => player.playerId == 'p1');
      final beforeP2 =
          match.players.firstWhere((player) => player.playerId == 'p2');

      final reduced = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
      );
      expect(reduced.isSuccess, isTrue);
      final after = reduced.state;
      final afterP1 =
          after.players.firstWhere((player) => player.playerId == 'p1');
      final afterP2 =
          after.players.firstWhere((player) => player.playerId == 'p2');

      expect(
        afterP1.session!.currentRound.stockCount,
        beforeP1.session!.currentRound.stockCount - 1,
      );
      expect(
        afterP2.session!.currentRound.stockCount,
        beforeP2.session!.currentRound.stockCount,
      );
      expect(
          afterP1.replay!.entries.length, beforeP1.replay!.entries.length + 1);
      expect(afterP2.replay!.entries.length, beforeP2.replay!.entries.length);
    });

    test('rejected actions do not change player state but are recorded', () {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'm2',
        matchSeed: 456,
        maxPlayers: 2,
        undoConfig: const UndoConfig(enabled: false),
      );
      var match = MatchState.newMatch(config: config);
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final before = match.players.single;
      final reduced = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(UndoAction()),
        ),
      );
      expect(reduced.isSuccess, isTrue);
      final after = reduced.state.players.single;

      expect(
        after.session!.currentRound.stock,
        equals(before.session!.currentRound.stock),
      );
      expect(
        after.session!.currentRound.waste,
        equals(before.session!.currentRound.waste),
      );
      expect(after.replay!.entries.length, before.replay!.entries.length + 1);
      expect(after.replay!.entries.last.accepted, isFalse);
      expect(
        after.replay!.entries.last.failureReason,
        ReplayFailureReason.undoDisabled,
      );
    });

    test('finish order is deterministic and follows event ordering', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p2')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      for (var i = 0; i < 3; i++) {
        match = tryReduceMatch(
          match,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        match = tryReduceMatch(
          match,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final p1 = match.players.firstWhere((player) => player.playerId == 'p1');
      final p2 = match.players.firstWhere((player) => player.playerId == 'p2');
      expect(p1.status, PlayerStatus.finished);
      expect(p2.status, PlayerStatus.finished);
      expect(p1.finishOrderIndex, 1);
      expect(p2.finishOrderIndex, 2);
    });

    test('replaying ordered events reproduces exact same final match state',
        () {
      final initial = buildInitialMatch();
      final events = <MatchEvent>[
        const JoinMatchEvent(playerId: 'p1'),
        const JoinMatchEvent(playerId: 'p2'),
        const StartMatchEvent(),
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(RemoveTableauCardAction(99)),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: PlayRoundAction(RemoveTableauCardAction(99)),
        ),
      ];

      var live = initial;
      for (final event in events) {
        live = tryReduceMatch(live, event).state;
      }
      final replayed = replayMatchEvents(initial, events);

      expect(replayed.toMap(), equals(live.toMap()));
    });
  });

  group('Competitive match scoring', () {
    MatchState buildStartedMatch({
      ScoreConfig scoreConfig = const ScoreConfig(),
    }) {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'comp',
        matchSeed: 999,
        maxPlayers: 2,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: scoreConfig,
        dealPolicyConfig: const DealPolicyConfig(mode: DealPolicyMode.random),
      );
      var state = MatchState.newMatch(config: config);
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p1')).state;
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p2')).state;
      state = tryReduceMatch(state, const StartMatchEvent()).state;
      return state;
    }

    test('first finisher receives configured firstFinishBonus', () {
      var state = buildStartedMatch();

      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final result = computeMatchResults(
        state,
        const MatchScoringConfig(firstFinishBonus: 100),
      );
      final p1 = result.placements.firstWhere((p) => p.playerId == 'p1');
      final p2 = result.placements.firstWhere((p) => p.playerId == 'p2');

      expect(p1.breakdown.firstFinishBonus, 100);
      expect(p2.breakdown.firstFinishBonus, 0);
    });

    test('tie resolution follows tieBreakerPolicy', () {
      var state = buildStartedMatch(
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
      );

      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final finishOrderResult = computeMatchResults(
        state,
        const MatchScoringConfig(
          tieBreakerPolicy: MatchTieBreakerPolicy.finishOrder,
        ),
      );
      final scoreResult = computeMatchResults(
        state,
        const MatchScoringConfig(
          tieBreakerPolicy: MatchTieBreakerPolicy.score,
        ),
      );

      expect(finishOrderResult.placements.first.playerId, 'p1');
      expect(scoreResult.placements.first.playerId, 'p2');
    });

    test(
      'players with same finish order are ranked by score when policy uses score',
      () {
        var state = buildStartedMatch(
          scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
        );

        // Both remain unfinished (finishOrderIndex null), scores diverge.
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;

        final finishOrderResult = computeMatchResults(
          state,
          const MatchScoringConfig(
            tieBreakerPolicy: MatchTieBreakerPolicy.finishOrder,
          ),
        );
        final scoreResult = computeMatchResults(
          state,
          const MatchScoringConfig(
            tieBreakerPolicy: MatchTieBreakerPolicy.score,
          ),
        );

        expect(finishOrderResult.placements.first.playerId, 'p1');
        expect(scoreResult.placements.first.playerId, 'p2');
      },
    );
  });

  group('Match finalization', () {
    MatchState buildFinalizableMatch() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'fin',
        matchSeed: 1001,
        maxPlayers: 2,
      );
      var state = MatchState.newMatch(config: config);
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p1')).state;
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p2')).state;
      state = tryReduceMatch(state, const StartMatchEvent()).state;
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      return state;
    }

    test('finalizeMatch produces stable result for same match state', () {
      final state = buildFinalizableMatch();
      const config = MatchFinalizationConfig(
        finishCondition: MatchFinishCondition.allPlayersFinished,
      );

      final a = finalizeMatch(state, config);
      final b = finalizeMatch(state, config);

      expect(a.isSuccess, isTrue);
      expect(b.isSuccess, isTrue);
      expect(a.result!.toMap(), equals(b.result!.toMap()));
    });

    test('finalized match rejects further submit actions', () {
      final state = buildFinalizableMatch();
      final finalized = finalizeMatch(
        state,
        const MatchFinalizationConfig(
          finishCondition: MatchFinishCondition.allPlayersFinished,
        ),
      );
      expect(finalized.isSuccess, isTrue);
      final finishedState = finalized.finishedMatchState!;

      final after = tryReduceMatch(
        finishedState,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
      );
      expect(after.isSuccess, isFalse);
      expect(after.failure?.code, MatchReduceFailureCode.matchAlreadyFinished);
    });

    test('finalizeMatch is idempotent on already finalized match state', () {
      final state = buildFinalizableMatch();
      const config = MatchFinalizationConfig(
        finishCondition: MatchFinishCondition.allPlayersFinished,
      );

      final first = finalizeMatch(state, config);
      expect(first.isSuccess, isTrue);
      final second = finalizeMatch(first.finishedMatchState!, config);
      expect(second.isSuccess, isTrue);
      expect(second.alreadyFinalized, isTrue);
      expect(second.result!.toMap(), equals(first.result!.toMap()));
    });

    test('FinalMatchResult serialization round-trip preserves equality', () {
      final state = buildFinalizableMatch();
      final finalized = finalizeMatch(
        state,
        const MatchFinalizationConfig(
          finishCondition: MatchFinishCondition.allPlayersFinished,
        ),
      );
      final result = finalized.result!;

      final decoded = FinalMatchResult.tryFromMap(result.toMap());
      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.toMap(), equals(result.toMap()));
      expect(decoded.value!.schemaVersion, result.schemaVersion);
      expect(decoded.value!.engineVersion, result.engineVersion);
    });
  });

  group('Server authority', () {
    ServerAuthorityState buildAuthority() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'srv',
        matchSeed: 111,
        maxPlayers: 2,
      );
      final match = MatchState.newMatch(config: config);
      return ServerAuthorityState.newAuthority(matchState: match);
    }

    test('duplicate same eventId is ignored without double apply', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;

      final before = authority.matchState;
      final duplicate = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );

      expect(duplicate.isSuccess, isTrue);
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.accepted, isFalse);
      expect(duplicate.state.matchState.toMap(), equals(before.toMap()));
      expect(duplicate.state.eventLog.last.outcome,
          ServerApplyStatus.duplicateIgnored);
    });

    test('out-of-order clientSeq is rejected deterministically', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 2,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;

      final outOfOrder = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 1,
          event: StartMatchEvent(),
        ),
      );

      expect(outOfOrder.accepted, isFalse);
      expect(outOfOrder.status, ServerApplyStatus.rejected);
      expect(outOfOrder.reason, ServerRejectReason.outOfOrderOrDuplicate);
      expect(outOfOrder.state.eventLog.last.rejectReason,
          ServerRejectReason.outOfOrderOrDuplicate);
    });

    test(
      'accepted events increment authoritativeSequence and update state correctly',
      () {
        var authority = buildAuthority();

        final join1 = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
        );
        expect(join1.accepted, isTrue);
        expect(join1.authoritativeSequence, 1);
        authority = join1.state;

        final join2 = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p2'),
          ),
        );
        expect(join2.accepted, isTrue);
        expect(join2.authoritativeSequence, 2);
        authority = join2.state;

        final start = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-2',
            clientSeq: 2,
            event: StartMatchEvent(),
          ),
        );
        expect(start.accepted, isTrue);
        expect(start.authoritativeSequence, 3);
        authority = start.state;

        final submit = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: SubmitMatchActionEvent(
              playerId: 'p1',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
        );
        expect(submit.accepted, isTrue);
        expect(submit.authoritativeSequence, 4);

        final player = submit.state.matchState.players
            .firstWhere((value) => value.playerId == 'p1');
        expect(player.replay, isNotNull);
        expect(player.replay!.entries, isNotEmpty);
        expect(player.latestFingerprint, isNotNull);
      },
    );

    test(
      'deterministic replay from accepted server log reproduces authoritative match state',
      () {
        var authority = buildAuthority();
        final initial = authority.matchState;

        for (final event in <ClientEvent>[
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p2'),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-2',
            clientSeq: 2,
            event: StartMatchEvent(),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: SubmitMatchActionEvent(
              playerId: 'p1',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-2',
            clientSeq: 2,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(RemoveTableauCardAction(99)),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-3',
            clientSeq: 3,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(UndoAction()),
            ),
          ),
        ]) {
          authority = applyClientEvent(authority, event).state;
        }

        final replayed = replayAcceptedServerEvents(
          initial,
          authority.eventLog,
        );
        expect(replayed.toMap(), equals(authority.matchState.toMap()));
      },
    );

    test('reconnect returns consistent state and does not mutate authority',
        () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 2,
          event: StartMatchEvent(),
        ),
      ).state;

      final beforeMap = authority.matchState.toMap();
      final beforeSeq = authority.matchState.authoritativeSequence;
      final resultA = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 0,
        ),
      );
      final resultB = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 0,
        ),
      );

      expect(resultA.isSuccess, isTrue);
      expect(resultA.snapshot?.toMap(), equals(resultB.snapshot?.toMap()));
      expect(resultA.authoritativeSequence, beforeSeq);
      expect(authority.matchState.toMap(), equals(beforeMap));
      expect(authority.matchState.authoritativeSequence, beforeSeq);
    });

    test('reconnect detects fingerprint mismatch and flags full resync', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 2,
          event: StartMatchEvent(),
        ),
      ).state;

      final reconnect = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 2,
          lastKnownFingerprint: 'wrong-fingerprint',
        ),
      );

      expect(reconnect.isSuccess, isTrue);
      expect(reconnect.mustFullyResync, isTrue);
    });

    test('reconnect does not change authoritativeSequence', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      final beforeSeq = authority.matchState.authoritativeSequence;

      final reconnect = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 1,
        ),
      );

      expect(reconnect.isSuccess, isTrue);
      expect(reconnect.authoritativeSequence, beforeSeq);
      expect(authority.matchState.authoritativeSequence, beforeSeq);
    });
  });

  test('engine source does not call DateTime.now', () {
    final source = File('lib/tripeaks_engine.dart').readAsStringSync();
    expect(source.contains('DateTime.now('), isFalse);
  });
}

List<Card> _buildDeck({
  required Map<int, Card> tableauOverrides,
  required Card waste,
}) {
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  for (final entry in tableauOverrides.entries) {
    _placeCard(deck, entry.key, entry.value);
  }
  return deck;
}

List<Card> _buildPeakBonusDeck() {
  return _buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      0: const Card(Rank.five, Suit.hearts),
      1: const Card(Rank.ten, Suit.spades),
      2: const Card(Rank.seven, Suit.diamonds),
      3: const Card(Rank.three, Suit.diamonds),
      4: const Card(Rank.four, Suit.spades),
      5: const Card(Rank.jack, Suit.diamonds),
      6: const Card(Rank.ten, Suit.hearts),
      7: const Card(Rank.eight, Suit.clubs),
      8: const Card(Rank.nine, Suit.diamonds),
      9: const Card(Rank.two, Suit.clubs),
      10: const Card(Rank.ace, Suit.diamonds),
      11: const Card(Rank.two, Suit.hearts),
      12: const Card(Rank.nine, Suit.clubs),
      13: const Card(Rank.ten, Suit.diamonds),
      14: const Card(Rank.jack, Suit.clubs),
      15: const Card(Rank.ten, Suit.clubs),
      16: const Card(Rank.jack, Suit.spades),
      17: const Card(Rank.queen, Suit.hearts),
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.diamonds),
      20: const Card(Rank.four, Suit.hearts),
      21: const Card(Rank.three, Suit.spades),
      22: const Card(Rank.six, Suit.diamonds),
      23: const Card(Rank.seven, Suit.clubs),
      24: const Card(Rank.eight, Suit.diamonds),
      25: const Card(Rank.jack, Suit.hearts),
      26: const Card(Rank.queen, Suit.clubs),
      27: const Card(Rank.king, Suit.diamonds),
    },
  );
}

List<Card> _buildStreakUnlockDeck() {
  return _buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.three, Suit.clubs),
      22: const Card(Rank.two, Suit.clubs),
      23: const Card(Rank.ace, Suit.clubs),
      24: const Card(Rank.king, Suit.clubs),
      25: const Card(Rank.queen, Suit.clubs),
      26: const Card(Rank.jack, Suit.clubs),
      27: const Card(Rank.ten, Suit.clubs),
    },
  );
}

List<Card> _buildBonusSlotTargetDeck() {
  final deck = _buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.two, Suit.diamonds),
    },
  );
  _placeCard(deck, 29, const Card(Rank.three, Suit.hearts));
  return deck;
}

List<Card> _buildJokerConsumeDeck() {
  return _buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.king, Suit.hearts),
    },
  );
}

List<Card> _buildHighTierUnlockDeck() {
  return _buildDeck(
    waste: const Card(Rank.queen, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.king, Suit.clubs),
      19: const Card(Rank.ace, Suit.clubs),
      20: const Card(Rank.king, Suit.hearts),
    },
  );
}

void _placeCard(List<Card> deck, int position, Card card) {
  final currentIndex = deck.indexOf(card);
  if (currentIndex == -1) {
    throw ArgumentError('Card $card is not present in standard deck.');
  }

  final temp = deck[position];
  deck[position] = deck[currentIndex];
  deck[currentIndex] = temp;
}

List<Card> _buildAlwaysLostDeck({required Card waste}) {
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  _placeCard(deck, 51, const Card(Rank.ace, Suit.hearts));

  final exposedCandidates = deck
      .where(
        (card) =>
            card.rank != Rank.two &&
            card.rank != Rank.king &&
            card != waste &&
            card != const Card(Rank.ace, Suit.hearts),
      )
      .take(10)
      .toList();
  for (var i = 0; i < exposedCandidates.length; i++) {
    _placeCard(deck, 18 + i, exposedCandidates[i]);
  }

  return deck;
}

List<Card> _buildDeckWithBottomRow({
  required Card waste,
  required List<Card> bottomRow,
}) {
  if (bottomRow.length != 10) {
    throw ArgumentError.value(
        bottomRow.length, 'bottomRow.length', 'Must be 10');
  }
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  for (var i = 0; i < bottomRow.length; i++) {
    _placeCard(deck, 18 + i, bottomRow[i]);
  }
  return deck;
}

TriPeaksState _applyTryActions(
  TriPeaksState initial,
  List<TriPeaksAction> actions,
) {
  var state = initial;
  for (final action in actions) {
    state = tryReduceTriPeaks(state, action).state;
  }
  return state;
}

MatchScoreState _applyMatchEvents(
  MatchScoreState initial,
  List<MatchScoreEvent> events,
) {
  var state = initial;
  for (final event in events) {
    state = reduceMatchScore(state, event);
  }
  return state;
}
