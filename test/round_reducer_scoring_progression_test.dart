import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - scoring progression', () {
    test('default scoring: tableau +5, draw +0, invalid +0', () {
      final deck = buildDeck(
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
      expect(state.scoreState.currentMultiplier, 1);
      expect(state.scoreState.lastBreakdown.totalDelta, 5);

      state = reduceTriPeaks(state, const DrawFromStockAction());
      expect(state.scoreState.totalScore, 5);
      expect(state.scoreState.lastDelta, 0);
      expect(state.scoreState.movesCount, 2);
      expect(state.scoreState.currentMultiplier, 1);
      expect(state.scoreState.lastBreakdown.drawPoints, 0);

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );
      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, 0);
      expect(invalid.state.scoreState.totalScore, 5);
      expect(invalid.state.scoreState.lastDelta, 0);
      expect(invalid.state.scoreState.movesCount, 3);
      expect(invalid.appliedMultiplier, 1);
      expect(invalid.scoreBreakdown.totalDelta, 0);
      expect(
        invalid.scoreBreakdown,
        equals(invalid.state.scoreState.lastBreakdown),
      );
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
      expect(invalid.appliedMultiplier, 1);
      expect(invalid.scoreBreakdown.invalidPenaltyPoints, -3);
    });

    test('negative total score can be disabled with clamped penalty', () {
      final state = TriPeaksState.newGame(
        seed: 21,
        scoreConfig: const ScoreConfig(
          penaltyInvalidAction: -3,
          allowNegativeTotalScore: false,
        ),
      );

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, 0);
      expect(invalid.state.scoreState.totalScore, 0);
      expect(invalid.state.scoreState.lastDelta, 0);
      expect(invalid.state.scoreState.movesCount, 1);
      expect(invalid.scoreBreakdown.invalidPenaltyPoints, 0);
      expect(invalid.scoreBreakdown.totalDelta, 0);
    });

    test('negative score clamp applies only when delta crosses below zero', () {
      var state = TriPeaksState.newGame(
        deck: buildDeck(
          tableauOverrides: <int, Card>{
            18: const Card(Rank.six, Suit.clubs),
          },
          waste: const Card(Rank.seven, Suit.hearts),
        ),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          penaltyInvalidAction: -3,
          allowNegativeTotalScore: false,
        ),
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, -3);
      expect(invalid.state.scoreState.totalScore, 2);
      expect(invalid.state.scoreState.lastDelta, -3);
      expect(invalid.scoreBreakdown.invalidPenaltyPoints, -3);
      expect(invalid.scoreBreakdown.totalDelta, -3);
    });

    test('negative score clamp partially applies penalty at floor', () {
      var state = TriPeaksState.newGame(
        deck: buildDeck(
          tableauOverrides: <int, Card>{
            18: const Card(Rank.six, Suit.clubs),
          },
          waste: const Card(Rank.seven, Suit.hearts),
        ),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 2,
          penaltyInvalidAction: -3,
          allowNegativeTotalScore: false,
        ),
      );

      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, -2);
      expect(invalid.state.scoreState.totalScore, 0);
      expect(invalid.state.scoreState.lastDelta, -2);
      expect(invalid.scoreBreakdown.invalidPenaltyPoints, -2);
      expect(invalid.scoreBreakdown.totalDelta, -2);
      expect(
        invalid.scoreBreakdown,
        equals(invalid.state.scoreState.lastBreakdown),
      );
    });

    test('multiplier defaults preserve legacy behavior', () {
      final state = TriPeaksState.newGame(deck: buildStreakUnlockDeck());
      final first = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
        tick: 1,
      );
      expect(first.isSuccess, isTrue);
      expect(first.appliedMultiplier, 1);
      expect(first.scoreBreakdown.tableauBasePoints, 5);
      expect(first.scoreBreakdown.multiplierExtraPoints, 0);
      expect(first.scoreDelta, 5);
    });

    test('round base points progression compounds per round', () {
      final config = const ScoreConfig(
        pointsTableauToWaste: 10,
        roundBasePointsGrowthBps: 2000,
      );
      final r1 = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 1,
      );
      final r2 = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 2,
      );
      final r3 = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 3,
      );

      expect(
        tryReduceTriPeaks(r1, const RemoveTableauCardAction(18)).scoreDelta,
        10,
      );
      expect(
        tryReduceTriPeaks(r2, const RemoveTableauCardAction(18)).scoreDelta,
        12,
      );
      expect(
        tryReduceTriPeaks(r3, const RemoveTableauCardAction(18)).scoreDelta,
        14,
      );
    });

    test('round base points progression floors each step', () {
      final config = const ScoreConfig(
        pointsTableauToWaste: 7,
        roundBasePointsGrowthBps: 1500,
      );
      final r2 = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 2,
      );
      final r3 = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 3,
      );

      expect(
        tryReduceTriPeaks(r2, const RemoveTableauCardAction(18)).scoreDelta,
        8,
      );
      expect(
        tryReduceTriPeaks(r3, const RemoveTableauCardAction(18)).scoreDelta,
        9,
      );
    });

    test('session rounds apply compounding base points', () {
      final config = const ScoreConfig(
        pointsTableauToWaste: 10,
        roundBasePointsGrowthBps: 2000,
      );
      final decks = <List<Card>>[
        buildStreakUnlockDeck(),
        buildStreakUnlockDeck(),
        buildStreakUnlockDeck(),
      ];
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: decks,
        scoreConfig: config,
      );

      final r1 = tryReduceTriPeaks(
        session.currentRound,
        const RemoveTableauCardAction(18),
      );
      expect(r1.scoreDelta, 10);

      session = reduceTriPeaksSession(
        session,
        const AbortRoundAction(),
      );
      final r2 = tryReduceTriPeaks(
        session.currentRound,
        const RemoveTableauCardAction(18),
      );
      expect(r2.scoreDelta, 12);
    });

    test('step multiplier uses pre-increment streak boundaries', () {
      final config = ScoreConfig(
        streakStepSize: 3,
        multiplierStepIncrement: 1,
        multiplierMax: 5,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );

      final r1 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
        tick: 1,
      );
      state = r1.state;
      expect(r1.appliedMultiplier, 1);
      expect(state.streakState.currentStreak, 1);

      final r2 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(19),
        tick: 2,
      );
      state = r2.state;
      expect(r2.appliedMultiplier, 1);
      expect(state.streakState.currentStreak, 2);

      final r3 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(20),
        tick: 3,
      );
      state = r3.state;
      expect(r3.appliedMultiplier, 1);
      expect(state.streakState.currentStreak, 3);

      final r4 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(21),
        tick: 4,
      );
      state = r4.state;
      expect(r4.appliedMultiplier, 2);
      expect(state.streakState.currentStreak, 4);
    });

    test('multiplier applies only to tableau base points', () {
      var state = TriPeaksState.newGame(
        deck: buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 10,
          pointsPeakCleared: 50,
          streakStepSize: 1,
          multiplierStepIncrement: 1,
          multiplierMax: 3,
        ),
      );
      TriPeaksReduceResult? last;
      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        last = tryReduceTriPeaks(state, RemoveTableauCardAction(index));
        state = last.state;
      }
      expect(last, isNotNull);
      expect(last!.scoreBreakdown.tableauBasePoints, 10);
      expect(last.scoreBreakdown.appliedMultiplier, 3);
      expect(last.scoreBreakdown.multiplierExtraPoints, 20);
      expect(last.scoreBreakdown.peakBonusPoints, 50);
      expect(last.scoreBreakdown.totalDelta, 80);
      final draw = tryReduceTriPeaks(state, const DrawFromStockAction());
      expect(draw.appliedMultiplier, 1);
      expect(draw.scoreBreakdown.tableauBasePoints, 0);
      expect(draw.scoreBreakdown.multiplierExtraPoints, 0);
      expect(draw.scoreBreakdown.peakBonusPoints, 0);
      expect(draw.scoreBreakdown.drawPoints, 0);
    });
  });
}
