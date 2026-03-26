import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - core and scoring', () {
    test('starts with bottom row exposed', () {
      final state = TriPeaksState.newGame(seed: 42);

      expect(
        state.exposedTableauIndices,
        equals(List<int>.generate(10, (i) => 18 + i)),
      );
    });

    test('removes an exposed adjacent card to waste', () {
      final deck = buildDeck(
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
      final deck = buildDeck(
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
      final deck = buildDeck(
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
      final deck = buildDeck(
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

    test('stock size progression uses defaults at round 1', () {
      final state = TriPeaksState.newGame(seed: 7);

      expect(state.stockCount, 21);
    });

    test('stock size progression decreases every N rounds', () {
      final rules = const RoundRulesConfig(
        startStockSize: 21,
        stockDecreaseEveryRounds: 2,
        minStockSize: 12,
      );
      final r1 = TriPeaksState.newGame(
        seed: 1,
        roundNumber: 1,
        roundRulesConfig: rules,
      );
      final r2 = TriPeaksState.newGame(
        seed: 1,
        roundNumber: 2,
        roundRulesConfig: rules,
      );
      final r3 = TriPeaksState.newGame(
        seed: 1,
        roundNumber: 3,
        roundRulesConfig: rules,
      );
      final r4 = TriPeaksState.newGame(
        seed: 1,
        roundNumber: 4,
        roundRulesConfig: rules,
      );

      expect(r1.stockCount, 21);
      expect(r2.stockCount, 20);
      expect(r3.stockCount, 20);
      expect(r4.stockCount, 19);
    });

    test('stock size progression respects minimum cap', () {
      final rules = const RoundRulesConfig(
        startStockSize: 14,
        stockDecreaseEveryRounds: 1,
        minStockSize: 12,
      );
      final r5 = TriPeaksState.newGame(
        seed: 1,
        roundNumber: 5,
        roundRulesConfig: rules,
      );

      expect(r5.stockCount, 12);
    });

    test('stock size validation uses layout-derived availability', () {
      final base = TriPeaksState.newGame(seed: 2);
      final available = 52 - base.tableau.length - 1;
      final rules = RoundRulesConfig(
        startStockSize: available + 1,
        stockDecreaseEveryRounds: 2,
        minStockSize: 0,
      );

      expect(
        () => TriPeaksState.newGame(seed: 2, roundRulesConfig: rules),
        throwsArgumentError,
      );
    });

    test('session rounds apply stock size progression', () {
      final rules = const RoundRulesConfig(
        startStockSize: 21,
        stockDecreaseEveryRounds: 2,
        minStockSize: 12,
      );
      final decks = <List<Card>>[
        buildStreakUnlockDeck(),
        buildStreakUnlockDeck(),
        buildStreakUnlockDeck(),
      ];
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: decks,
        roundRulesConfig: rules,
      );

      expect(session.currentRound.stockCount, 21);
      session = reduceTriPeaksSession(session, const AbortRoundAction());
      expect(session.currentRound.stockCount, 20);
      session = reduceTriPeaksSession(session, const AbortRoundAction());
      expect(session.currentRound.stockCount, 20);
    });

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

    test('time bonus mode does not stack with streak multiplier', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
        streakStepSize: 1,
        multiplierStepIncrement: 5,
        multiplierMax: 6,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );

      final r1 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );
      state = r1.state;
      expect(r1.appliedMultiplier, 1);
      expect(state.streakState.currentStreak, 1);

      final r2 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(19),
      );
      expect(r2.appliedMultiplier, 2);
      expect(r2.scoreBreakdown.multiplierExtraPoints, 5);
      expect(r2.state.streakState.currentStreak, 2);
    });

    test('time bonus multiplier uses pre-move timer and caps', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 4,
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
      expect(r1.appliedMultiplier, 1);
      expect(r1.state.timeBonusTimerState.remainingSeconds, 2);
      state = r1.state;

      final r2 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(19),
        tick: 2,
      );
      expect(r2.appliedMultiplier, 2);
      expect(r2.state.timeBonusTimerState.remainingSeconds, 4);
      expect(r2.state.timeBonusTimerState.stepCount, 1);
      state = r2.state;

      final r3 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(20),
        tick: 3,
      );
      expect(r3.appliedMultiplier, 3);
      expect(r3.state.timeBonusTimerState.remainingSeconds, 4);
      expect(r3.state.timeBonusTimerState.stepCount, 2);
    });

    test('time bonus draw resets timer and increments token', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );

      final r1 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );
      state = r1.state;
      final token = state.timeBonusTimerState.deadlineToken;
      expect(state.timeBonusTimerState.remainingSeconds, 2);

      final draw = tryReduceTriPeaks(state, const DrawFromStockAction());
      expect(draw.state.timeBonusTimerState.remainingSeconds, 0);
      expect(draw.state.timeBonusTimerState.deadlineToken, token + 1);
    });

    test('draw does not increment token when timer already zero', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
      );
      final state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );
      final token = state.timeBonusTimerState.deadlineToken;

      final draw = tryReduceTriPeaks(state, const DrawFromStockAction());
      expect(draw.state.timeBonusTimerState.remainingSeconds, 0);
      expect(draw.state.timeBonusTimerState.deadlineToken, token);
    });

    test('time bonus expiry validates token and does not affect bonus slots',
        () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );

      final r1 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );
      state = r1.state;
      final token = state.timeBonusTimerState.deadlineToken;
      final openSlots = state.bonusSlotsState.openSlotsCount;

      final stale = tryReduceTriPeaks(
        state,
        TimeBonusExpiredAction(deadlineToken: token + 1),
      );
      expect(stale.isSuccess, isFalse);
      expect(stale.error?.code, TriPeaksErrorCode.staleTimeBonusExpiry);

      final expired = tryReduceTriPeaks(
        state,
        TimeBonusExpiredAction(deadlineToken: token),
      );
      expect(expired.isSuccess, isTrue);
      expect(expired.state.timeBonusTimerState.remainingSeconds, 0);
      expect(expired.state.bonusSlotsState.openSlotsCount, openSlots);

      final strikeExpiry = tryReduceTriPeaks(
        expired.state,
        const StrikeTimerExpiredAction(deadlineToken: 1),
      );
      expect(strikeExpiry.isSuccess, isFalse);
      expect(
        strikeExpiry.error?.code,
        TriPeaksErrorCode.strikeTimerDisabled,
      );

      final notArmed = tryReduceTriPeaks(
        expired.state,
        TimeBonusExpiredAction(deadlineToken: token),
      );
      expect(notArmed.isSuccess, isFalse);
      expect(notArmed.error?.code, TriPeaksErrorCode.timeBonusTimerNotArmed);
    });

    test('time bonus undo restores timer state', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
        undoConfig: const UndoConfig(enabled: true, maxSteps: 5),
      );

      final r1 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );
      state = r1.state;
      final snapshot = state.timeBonusTimerState;

      final r2 = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(19),
      );
      state = r2.state;

      final undo = tryReduceTriPeaks(state, const UndoAction());
      expect(undo.state.timeBonusTimerState, snapshot);
    });

    test('time bonus timer invariants hold', () {
      final config = const ScoreConfig(
        multiplierMode: ScoreMultiplierMode.timeBonus,
        timeBonusSecondsPerMove: 2,
        timeBonusMaxSeconds: 10,
      );
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: config,
      );

      state = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      ).state;
      state = tryReduceTriPeaks(state, const DrawFromStockAction()).state;

      expect(
          state.timeBonusTimerState.remainingSeconds, greaterThanOrEqualTo(0));
      expect(state.timeBonusTimerState.stepCount, greaterThanOrEqualTo(0));
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

    test('breakdown invariants hold and match score state/result', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 7,
          pointsDrawFromStock: 2,
          penaltyInvalidAction: -3,
          streakStepSize: 2,
          multiplierStepIncrement: 1,
          multiplierMax: 4,
        ),
      );
      final results = <TriPeaksReduceResult>[
        tryReduceTriPeaks(state, const RemoveTableauCardAction(18)),
      ];
      state = results.last.state;
      results.add(tryReduceTriPeaks(state, const DrawFromStockAction()));
      state = results.last.state;
      results.add(tryReduceTriPeaks(state, const RemoveTableauCardAction(99)));

      for (final result in results) {
        final breakdown = result.scoreBreakdown;
        expect(breakdown.appliedMultiplier, greaterThanOrEqualTo(1));
        expect(
          breakdown.multiplierExtraPoints,
          breakdown.tableauBasePoints * (breakdown.appliedMultiplier - 1),
        );
        expect(
          breakdown.totalDelta,
          breakdown.tableauBasePoints +
              breakdown.multiplierExtraPoints +
              breakdown.peakBonusPoints +
              breakdown.drawPoints +
              breakdown.invalidPenaltyPoints +
              breakdown.endRoundRemainingStockBonusPoints,
        );
        expect(result.scoreDelta, breakdown.totalDelta);
        expect(result.state.scoreState.lastDelta, breakdown.totalDelta);
        expect(result.scoreBreakdown,
            equals(result.state.scoreState.lastBreakdown));
        expect(result.appliedMultiplier,
            result.state.scoreState.currentMultiplier);
      }
    });

    test('undo restores prior score state and result breakdown mirrors restore',
        () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 2),
        undoConfig: const UndoConfig(enabled: true, maxSteps: 5),
      );
      final first = tryReduceTriPeaks(state, const DrawFromStockAction());
      state = first.state;
      final restoredSnapshot = state.scoreState;

      final second = tryReduceTriPeaks(state, const DrawFromStockAction());
      state = second.state;
      expect(state.scoreState.totalScore, 4);

      final undo = tryReduceTriPeaks(state, const UndoAction());
      expect(undo.isSuccess, isTrue);
      expect(undo.scoreDelta, 0);
      expect(undo.state.scoreState.totalScore, restoredSnapshot.totalScore);
      expect(undo.state.scoreState.lastDelta, restoredSnapshot.lastDelta);
      expect(
        undo.state.scoreState.currentMultiplier,
        restoredSnapshot.currentMultiplier,
      );
      expect(
          undo.state.scoreState.lastBreakdown, restoredSnapshot.lastBreakdown);
      expect(undo.scoreBreakdown, equals(restoredSnapshot.lastBreakdown));
      expect(undo.appliedMultiplier, restoredSnapshot.currentMultiplier);
    });

    test('win awards remaining stock bonus exactly once', () {
      final config = const ScoreConfig(pointsPerRemainingStockCardOnWin: 2);
      final deck = buildDeckWithBottomRow(
        waste: const Card(Rank.six, Suit.spades),
        bottomRow: <Card>[
          const Card(Rank.five, Suit.clubs),
          const Card(Rank.two, Suit.clubs),
          const Card(Rank.three, Suit.clubs),
          const Card(Rank.four, Suit.clubs),
          const Card(Rank.five, Suit.hearts),
          const Card(Rank.six, Suit.hearts),
          const Card(Rank.seven, Suit.hearts),
          const Card(Rank.eight, Suit.hearts),
          const Card(Rank.nine, Suit.hearts),
          const Card(Rank.ten, Suit.hearts),
        ],
      );
      final base = TriPeaksState.newGame(deck: deck, scoreConfig: config);
      final map = base.toMap();
      map['removed'] = List<bool>.generate(
        28,
        (index) => index != 18,
        growable: false,
      );
      final restored = TriPeaksState.tryFromMap(map);
      expect(restored.isSuccess, isTrue);
      final state = restored.value!;

      final result = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state.isWon, isTrue);
      final bonus =
          result.state.stockCount * config.pointsPerRemainingStockCardOnWin;
      expect(
        result.scoreBreakdown.endRoundRemainingStockBonusPoints,
        bonus,
      );
      expect(result.scoreBreakdown.totalDelta, result.scoreDelta);

      final after = tryReduceTriPeaks(result.state, const UndoAction());
      expect(after.isSuccess, isTrue);
      expect(after.state.isWon, isFalse);
      final reapply = tryReduceTriPeaks(
        after.state,
        const RemoveTableauCardAction(18),
      );
      expect(reapply.isSuccess, isTrue);
      expect(
        reapply.scoreBreakdown.endRoundRemainingStockBonusPoints,
        bonus,
      );
    });
  });
}
