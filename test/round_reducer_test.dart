import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

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
