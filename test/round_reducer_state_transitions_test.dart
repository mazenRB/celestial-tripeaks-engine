import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - undo streak errors peaks', () {
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

      final finalA = applyTryActions(stateA, actions);
      final finalB = applyTryActions(stateB, actions);

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
      expect(state.stockCount, 17);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 18);
      expect(state.undoStepsAvailable, 2);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 19);
      expect(state.undoStepsAvailable, 1);

      state = reduceTriPeaks(state, const UndoAction());
      expect(state.stockCount, 20);
      expect(state.undoStepsAvailable, 0);

      final noUndo = tryReduceTriPeaks(state, const UndoAction());
      expect(noUndo.isSuccess, isFalse);
      expect(noUndo.error?.code, TriPeaksErrorCode.nothingToUndo);
      expect(noUndo.state.stockCount, 20);
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

        final finalA = applyTryActions(initialA, actions);
        final finalB = applyTryActions(initialB, actions);

        expect(finalA.stock, equals(finalB.stock));
        expect(finalA.waste, equals(finalB.waste));
        expect(finalA.removed, equals(finalB.removed));
        expect(finalA.scoreState.totalScore, finalB.scoreState.totalScore);
        expect(finalA.undoStepsAvailable, finalB.undoStepsAvailable);
      },
    );

    test('consecutive valid tableau moves increase streak', () {
      final deck = buildDeckWithBottomRow(
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
      final deck = buildDeckWithBottomRow(
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
      final deck = buildDeckWithBottomRow(
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
      final deck = buildDeckWithBottomRow(
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
      var state = TriPeaksState.newGame(deck: buildStreakUnlockDeck());
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
      var state = TriPeaksState.newGame(deck: buildStreakUnlockDeck());
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
      var state = TriPeaksState.newGame(deck: buildStreakUnlockDeck());
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
        deck: buildPeakBonusDeck(),
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
        deck: buildPeakBonusDeck(),
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
        deck: buildPeakBonusDeck(),
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
        deck: buildPeakBonusDeck(),
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
  });
}
