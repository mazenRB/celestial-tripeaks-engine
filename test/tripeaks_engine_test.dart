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
        _buildStreakUnlockDeck(),
        _buildStreakUnlockDeck(),
        _buildStreakUnlockDeck(),
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
      final state = TriPeaksState.newGame(deck: _buildStreakUnlockDeck());
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
        deck: _buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 1,
      );
      final r2 = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 2,
      );
      final r3 = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
        scoreConfig: config,
        roundNumber: 2,
      );
      final r3 = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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
        _buildStreakUnlockDeck(),
        _buildStreakUnlockDeck(),
        _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildPeakBonusDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
      final deck = _buildDeckWithBottomRow(
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

    test('tierRandomRank spawns low-tier rank from 2..10 domain', () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildHighTierUnlockDeck(),
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
          deck: _buildStreakUnlockDeck(),
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
          deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18), tick: 1);
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19), tick: 2);
      final nonceBeforeSpawn = state.bonusAnchorSpawnNonce;
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20), tick: 3);

      final expectedRank = _expectedTierRandomRank(
        roundSeed: state.roundSeed,
        spawnNonce: nonceBeforeSpawn,
        slotIndex: 2,
        tier: BonusSlotAnchorTier.low,
      );
      expect(state.bonusSlotsState.slots[1].single.rank, expectedRank);
    });

    test('stockTopCard opens slots 2 and 3 by consuming stock in order', () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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
        deck: _buildStreakUnlockDeck(),
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

    test('actionable bonus slot indices match use-slot acceptance predicate',
        () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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

    test('stockTopCard draw close merges spawned slot card and undo restores',
        () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
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

  group('TriPeaks session reducer', () {
    test('supports 1, 3, 6, and 10 rounds via ruleset', () {
      final one = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.oneRound,
        seed: 1,
      );
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

      expect(one.ruleset.roundsPerGame, 1);
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
      final fullStockSize = _layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
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
        roundRulesConfig: roundRules,
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
      expect(
        session.roundResults.last.finalScore,
        session.currentRound.scoreState.totalScore,
      );
      expect(
        session.cumulativeFinishedRoundsScoreTotal,
        session.roundResults.last.finalScore,
      );
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.cumulativeFinishedRoundsScoreTotal,
      );

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRoundNumber, 2);
      expect(session.roundsCompleted, 1);
      expect(
        session.cumulativeFinishedRoundsScoreTotal,
        session.roundResults.first.finalScore,
      );
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.cumulativeFinishedRoundsScoreTotal +
            session.currentRound.scoreState.totalScore,
      );
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

    test('session decode derives missing roundSeed from session seed + index',
        () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 40,
      );
      final map = session.toMap();
      final currentRound = map['currentRound'] as Map<String, dynamic>;
      currentRound.remove('roundSeed');

      final decoded = TriPeaksSessionState.tryFromMap(map);
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;
      expect(restored.currentRound.roundSeed, 40);
    });

    test('session status helper transitions deterministically', () {
      final fullStockSize = _layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: <List<Card>>[
          _buildAlwaysLostDeck(
            waste: const Card(Rank.ace, Suit.clubs),
          ),
          _buildAlwaysLostDeck(
            waste: const Card(Rank.king, Suit.clubs),
          ),
          _buildAlwaysLostDeck(
            waste: const Card(Rank.queen, Suit.clubs),
          ),
        ],
        roundRulesConfig: roundRules,
      );
      expect(session.status, TriPeaksSessionStatus.inProgress);

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.currentRound.isLost, isTrue);
      expect(session.status, TriPeaksSessionStatus.lost);

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.status, TriPeaksSessionStatus.inProgress);

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.status, TriPeaksSessionStatus.lost);

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.isSessionFinished, isTrue);
      expect(session.status, TriPeaksSessionStatus.gameOver);
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
      final expectedRoundTwo = TriPeaksState.newGame(
        seed: 18,
        roundNumber: 2,
        roundRulesConfig: session.roundRulesConfig,
      );

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
      expect(next.roundResults.single.finalScore, 0);
      expect(next.currentRound.tableau, equals(expectedRoundTwo.tableau));
      expect(next.currentRound.waste, equals(expectedRoundTwo.waste));
      expect(next.currentRound.stock, equals(expectedRoundTwo.stock));
    });

    test('cumulative totals are deterministic and avoid double counting', () {
      final fullStockSize = _layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: <List<Card>>[
          _buildAlwaysLostDeck(
            waste: const Card(Rank.ace, Suit.clubs),
          ),
          _buildAlwaysLostDeck(
            waste: const Card(Rank.king, Suit.clubs),
          ),
          _buildAlwaysLostDeck(
            waste: const Card(Rank.queen, Suit.clubs),
          ),
        ],
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
        roundRulesConfig: roundRules,
      );

      session = reduceTriPeaksSession(
        session,
        const PlayRoundAction(DrawFromStockAction()),
      );
      expect(session.isCurrentRoundFinished, isFalse);
      expect(session.cumulativeFinishedRoundsScoreTotal, 0);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.currentRound.scoreState.totalScore,
      );

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      final finishedRoundOneScore = session.currentRound.scoreState.totalScore;
      expect(session.isCurrentRoundFinished, isTrue);
      expect(session.roundResults.last.finalScore, finishedRoundOneScore);
      expect(session.cumulativeFinishedRoundsScoreTotal, finishedRoundOneScore);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        finishedRoundOneScore,
      );

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRound.scoreState.totalScore, 0);
      expect(session.cumulativeFinishedRoundsScoreTotal, finishedRoundOneScore);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        finishedRoundOneScore,
      );
    });

    test('null finalScore values are skipped by cumulative finished total', () {
      final decode = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'lost',
        },
      );
      expect(decode.isSuccess, isTrue);
      expect(decode.value!.finalScore, isNull);

      final baseSession = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 99,
      );
      final map = baseSession.toMap();
      map['roundResults'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'lost',
        },
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 2,
          'outcome': 'aborted',
          'abortReason': 'userSkip',
          'finalScore': 7,
        },
      ];
      final rebuilt = TriPeaksSessionState.tryFromMap(map);
      expect(rebuilt.isSuccess, isTrue);
      final withLegacyResult = rebuilt.value!;

      expect(withLegacyResult.cumulativeFinishedRoundsScoreTotal, 7);
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

  group('Mode presets', () {
    test('preset ids are stable and parse deterministically', () {
      expect(TriPeaksModePreset.classic.modeId, 'classic');
      expect(TriPeaksModePreset.celestial.modeId, 'celestial');
      expect(
        TriPeaksModePreset.tryParseModeId('classic'),
        TriPeaksModePreset.classic,
      );
      expect(
        TriPeaksModePreset.tryParseModeId('celestial'),
        TriPeaksModePreset.celestial,
      );
      expect(TriPeaksModePreset.tryParseModeId('unknown'), isNull);
    });

    test('classic bundle matches standard solitaire preset', () {
      const bundle = TriPeaksModeBundle.classic;

      expect(bundle.preset, TriPeaksModePreset.classic);
      expect(bundle.ruleset, TriPeaksRuleset.oneRound);
      expect(bundle.scoreConfig.pointsTableauToWaste, 4096);
      expect(bundle.scoreConfig.penaltyInvalidAction, 20000);
      expect(bundle.scoreConfig.pointsPeakCleared, 200000);
      expect(bundle.scoreConfig.pointsPerRemainingStockCardOnWin, 50000);
      expect(bundle.scoreConfig.multiplierMode, ScoreMultiplierMode.streak);
      expect(
        bundle.roundRulesConfig.toMap(),
        const RoundRulesConfig(
          aceKingWrapAround: false,
          startStockSize: 23,
          stockDecreaseEveryRounds: 999999,
          minStockSize: 23,
        ).toMap(),
      );
      expect(
        bundle.undoConfig.toMap(),
        const UndoConfig(enabled: false, maxSteps: 0).toMap(),
      );
      expect(bundle.streakConfig.toMap(), const StreakConfig().toMap());
      expect(
        bundle.strikeTimerConfig.toMap(),
        const StrikeTimerConfig(enabled: false).toMap(),
      );
      expect(
        bundle.bonusSlotsConfig.toMap(),
        const BonusSlotsConfig(enabled: false).toMap(),
      );
      expect(
        bundle.dealPolicyConfig.toMap(),
        const DealPolicyConfig().toMap(),
      );
    });

    test('celestial bundle is fully populated and distinct', () {
      final bundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );

      expect(bundle.preset, TriPeaksModePreset.celestial);
      expect(bundle.ruleset, TriPeaksRuleset.tenRounds);
      expect(bundle.scoreConfig.pointsTableauToWaste, 4096);
      expect(bundle.scoreConfig.penaltyInvalidAction, 20000);
      expect(bundle.scoreConfig.pointsPeakCleared, 200000);
      expect(bundle.scoreConfig.pointsPerRemainingStockCardOnWin, 50000);
      expect(bundle.scoreConfig.multiplierMode, ScoreMultiplierMode.timeBonus);
      expect(bundle.roundRulesConfig.minStockSize, 16);
      expect(bundle.undoConfig.enabled, isFalse);
      expect(bundle.strikeTimerConfig.enabled, isFalse);
      expect(
        bundle.bonusSlotsConfig.spawnPolicy,
        BonusSlotSpawnPolicy.tierRandomRank,
      );
      expect(bundle.bonusSlotsConfig.spawnOnOpenSlot2AtStreak, 3);
      expect(bundle.bonusSlotsConfig.spawnOnOpenSlot3AtStreak, 8);
      expect(bundle.dealPolicyConfig.mode, DealPolicyMode.requireSolvable);
      expect(
        bundle.dealPolicyConfig.attemptSeedStrategy,
        AttemptSeedStrategy.fnv1aMix,
      );
      expect(bundle.dealPolicyConfig.maxAttempts, 200);
      expect(bundle.dealPolicyConfig.solverNodeLimit, 300000);
      expect(bundle, isNot(TriPeaksModeBundle.classic));
    });

    test('bundle fields can be reused across session replay and match setup',
        () {
      final bundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );
      final session = TriPeaksSessionState.newSession(
        ruleset: bundle.ruleset,
        seed: 42,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
      );
      final replay = TriPeaksReplay.newSession(
        seed: 42,
        ruleset: bundle.ruleset,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
      );
      final match = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'mode-test',
        matchSeed: 42,
        maxPlayers: 2,
        ruleset: bundle.ruleset,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
        dealPolicyConfig: bundle.dealPolicyConfig,
      );

      expect(session.ruleset, bundle.ruleset);
      expect(session.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(replay.ruleset, bundle.ruleset);
      expect(replay.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(match.ruleset, bundle.ruleset);
      expect(match.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(
        match.dealPolicyConfig.toMap(),
        bundle.dealPolicyConfig.toMap(),
      );
    });
  });

  group('Daily challenge', () {
    test('preset-backed daily config uses canonical mode ids', () {
      final classic = DailyChallengeConfig.forPreset(
        namespaceId: 'prod',
        preset: TriPeaksModePreset.classic,
      );
      final celestial = DailyChallengeConfig.forPreset(
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );

      expect(classic.modeId, 'classic');
      expect(celestial.modeId, 'celestial');
    });

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

    test('preset-backed daily helpers apply resolved bundles', () {
      const date = DateOnly(2026, 2, 20);
      final classicBundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.classic,
      );
      final celestialBundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );
      final classicSession = newDailySessionForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.classic,
      );
      final session = newDailySessionForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );
      final game = newDailyGameForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );

      expect(
        classicSession.ruleset.roundsPerGame,
        classicBundle.ruleset.roundsPerGame,
      );
      expect(
        session.ruleset.roundsPerGame,
        celestialBundle.ruleset.roundsPerGame,
      );
      expect(
        session.scoreConfig.toMap(),
        celestialBundle.scoreConfig.toMap(),
      );
      expect(
        session.roundRulesConfig.toMap(),
        celestialBundle.roundRulesConfig.toMap(),
      );
      expect(session.undoConfig.toMap(), celestialBundle.undoConfig.toMap());
      expect(
        session.strikeTimerConfig.toMap(),
        celestialBundle.strikeTimerConfig.toMap(),
      );
      expect(game.scoreConfig.toMap(), celestialBundle.scoreConfig.toMap());
      expect(
        game.roundRulesConfig.toMap(),
        celestialBundle.roundRulesConfig.toMap(),
      );
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
            result.finalScore,
          );
        }).toList(growable: false),
        equals(
          liveState.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
              result.finalScore,
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
            result.finalScore,
          );
        }).toList(growable: false),
        equals(
          rebuiltDecoded.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
              result.finalScore,
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

    test(
      'tierRandomRank anchor behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 11,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: liveState.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: liveState.ruleset,
          scoreConfig: liveState.scoreConfig,
          roundRulesConfig: liveState.roundRulesConfig,
          undoConfig: liveState.undoConfig,
          streakConfig: liveState.streakConfig,
          strikeTimerConfig: liveState.strikeTimerConfig,
          bonusSlotsConfig: liveState.bonusSlotsConfig,
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
        expect(
          liveState.currentRound.streakState.currentStreak,
          greaterThanOrEqualTo(3),
        );

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.isAnchor,
          isTrue,
        );
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.rank,
          liveState.currentRound.bonusSlotsState.slots[1].single.rank,
        );
        expect(
          rebuilt.currentRound.bonusAnchorSpawnNonce,
          liveState.currentRound.bonusAnchorSpawnNonce,
        );
        expect(sessionFingerprint(rebuilt), sessionFingerprint(liveState));
      },
    );

    test(
      'stockTopCard bonus behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 11,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: liveState.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: liveState.ruleset,
          scoreConfig: liveState.scoreConfig,
          roundRulesConfig: liveState.roundRulesConfig,
          undoConfig: liveState.undoConfig,
          streakConfig: liveState.streakConfig,
          strikeTimerConfig: liveState.strikeTimerConfig,
          bonusSlotsConfig: liveState.bonusSlotsConfig,
        );

        var guard = 0;
        while (liveState.currentRound.bonusSlotsState.openSlotsCount < 2 &&
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
        expect(liveState.currentRound.bonusSlotsState.openSlotsCount, 2);

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single,
          liveState.currentRound.bonusSlotsState.slots[1].single,
        );
        expect(rebuilt.currentRound.stock, liveState.currentRound.stock);
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
    test('mode bundle round-trip preserves classic and celestial bundles', () {
      final classicDecoded = TriPeaksModeBundle.tryFromMap(
        TriPeaksModeBundle.classic.toMap(),
      );
      final celestialDecoded = TriPeaksModeBundle.tryFromMap(
        TriPeaksModeBundle.celestial.toMap(),
      );

      expect(classicDecoded.isSuccess, isTrue);
      expect(classicDecoded.value, TriPeaksModeBundle.classic);
      expect(celestialDecoded.isSuccess, isTrue);
      expect(celestialDecoded.value, TriPeaksModeBundle.celestial);
    });

    test('mode bundle decode preserves nested values without re-resolving', () {
      final map = TriPeaksModeBundle.celestial.toMap();
      final scoreConfig = Map<String, dynamic>.from(
        map['scoreConfig'] as Map<String, dynamic>,
      );
      scoreConfig['pointsDrawFromStock'] = 7;
      map['scoreConfig'] = scoreConfig;

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.preset, TriPeaksModePreset.celestial);
      expect(decoded.value!.scoreConfig.pointsDrawFromStock, 7);
      expect(
        decoded.value!.scoreConfig.pointsDrawFromStock,
        isNot(TriPeaksModeBundle.celestial.scoreConfig.pointsDrawFromStock),
      );
    });

    test('mode bundle decode rejects unknown preset id', () {
      final map = TriPeaksModeBundle.classic.toMap();
      map['presetId'] = 'unknown';

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('mode bundle decode rejects invalid nested payload', () {
      final map = TriPeaksModeBundle.classic.toMap();
      final scoreConfig = Map<String, dynamic>.from(
        map['scoreConfig'] as Map<String, dynamic>,
      );
      scoreConfig['pointsDrawFromStock'] = 'bad';
      map['scoreConfig'] = scoreConfig;

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('round result finalScore is backward compatible', () {
      final legacy = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'won',
        },
      );
      expect(legacy.isSuccess, isTrue);
      expect(legacy.value!.finalScore, isNull);

      final current = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 2,
          'outcome': 'lost',
          'finalScore': 11,
        },
      );
      expect(current.isSuccess, isTrue);
      expect(current.value!.finalScore, 11);
    });

    test('round result decode rejects invalid finalScore type', () {
      final decoded = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'won',
          'finalScore': '11',
        },
      );
      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('bonus slots config round-trip supports stockTopCard', () {
      const config = BonusSlotsConfig(
        spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
      );
      final decoded = BonusSlotsConfig.tryFromMap(config.toMap());
      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.spawnPolicy, BonusSlotSpawnPolicy.stockTopCard);
    });

    test('bonus slots config map is stable (golden)', () {
      const config = BonusSlotsConfig(
        enabled: true,
        spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
        defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.high,
        lowTierAnchorRank: Rank.eight,
        highTierAnchorRank: Rank.king,
        jokerAcceptsAnyRank: false,
        jokerConsumedOnFirstUse: true,
        spawnOnOpenSlot2AtStreak: 3,
        spawnOnOpenSlot3AtStreak: 6,
        closeOnDraw: true,
        closeOnInvalidAction: true,
        maxSlots: 3,
      );
      expect(
        config.toMap(),
        equals(
          <String, dynamic>{
            'schemaVersion': 1,
            'type': 'bonus_slots_config',
            'enabled': true,
            'spawnPolicy': 'tierFixedRank',
            'defaultAnchorTierWhenUnknown': 'high',
            'lowTierAnchorRank': 'eight',
            'highTierAnchorRank': 'king',
            'jokerAcceptsAnyRank': false,
            'jokerConsumedOnFirstUse': true,
            'spawnOnOpenSlot2AtStreak': 3,
            'spawnOnOpenSlot3AtStreak': 6,
            'closeOnDraw': true,
            'closeOnInvalidAction': true,
            'maxSlots': 3,
          },
        ),
      );
    });

    test('anchor card map is stable (golden)', () {
      const anchor = Card.anchor(Rank.queen);
      expect(
        anchor.toMap(),
        equals(
          <String, dynamic>{
            'schemaVersion': 1,
            'type': 'card',
            'cardKind': 'anchor',
            'rank': 'queen',
          },
        ),
      );
    });

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
      expect(restored.roundSeed, progressed.roundSeed);
      expect(restored.bonusAnchorSpawnNonce, progressed.bonusAnchorSpawnNonce);
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

    test('replay map includes tierFixedRank bonus config deterministically',
        () {
      final replay = TriPeaksReplay.newSession(
        seed: 7,
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.low,
          lowTierAnchorRank: Rank.six,
          highTierAnchorRank: Rank.queen,
        ),
      );
      final map = replay.toMap();
      final bonus = map['bonusSlotsConfig'] as Map<String, dynamic>;
      expect(bonus['spawnPolicy'], 'tierFixedRank');
      expect(bonus['defaultAnchorTierWhenUnknown'], 'low');
      expect(bonus['lowTierAnchorRank'], 'six');
      expect(bonus['highTierAnchorRank'], 'queen');
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
      expect(stateFingerprint(state), '54f511b5');
    });
  });

  group('Save/Load', () {
    test('tierFixedRank round save/load keeps anchor state and fingerprint',
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
      expect(state.bonusSlotsState.slots[1].single.isAnchor, isTrue);

      final save = encodeSaveRound(state, savedAtSequence: 3);
      final loaded = decodeSaveRound(save);
      expect(loaded.isSuccess, isTrue);
      expect(
        loaded.value!.state.bonusSlotsState.slots[1].single.isAnchor,
        isTrue,
      );
      expect(
        stateFingerprint(loaded.value!.state),
        stateFingerprint(state),
      );
    });

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

  group('Authority runtime', () {
    MatchState buildInitialMatch({String matchId = 'runtime'}) {
      return MatchState.newMatch(
        config: MatchConfig(
          matchMode: MatchMode.realtime,
          matchId: matchId,
          matchSeed: 123,
          maxPlayers: 2,
        ),
      );
    }

    test('baseline starts at sequence 0 and first accepted event is 1',
        () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final restored = await runtime.restore('runtime');
      expect(restored.isSuccess, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 0);

      final apply = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'client-side-value-is-ignored',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );

      expect(apply.accepted, isTrue);
      expect(apply.authoritativeSequence, 1);

      final tail = await store.loadAcceptedEventsAfter('runtime', 0);
      expect(tail, hasLength(1));
      expect(tail.first.authoritativeSequence, 1);
    });

    test('append failure never returns accepted and state is not committed',
        () async {
      final store = InMemoryAuthorityStore(
        shouldFailAppend: (_, __) => true,
      );
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final result = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.rejected, isTrue);
      expect(
        result.failure?.code,
        AuthorityApplyFailureCode.durabilityFailure,
      );
      expect(runtime.state.matchState.authoritativeSequence, 0);
      expect(store.acceptedEvents('runtime'), isEmpty);
    });

    test('duplicate and rejected outcomes are not written to accepted log',
        () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final accepted = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(accepted.accepted, isTrue);

      final duplicate = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.authoritativeSequence, 1);
      expect(duplicate.lastAcceptedClientSeq, 1);

      final rejected = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 1,
          event: StartMatchEvent(),
        ),
      );
      expect(rejected.rejected, isTrue);
      expect(rejected.mustFullyResync, isTrue);

      expect(store.acceptedEvents('runtime'), hasLength(1));
    });

    test('restore rebuilds clientSeq and idempotency windows', () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
        config: const AuthorityRuntimeConfig(
          snapshotEveryAccepted: 1,
          processedClientEventIdsCapacityPerPlayer: 1000,
        ),
      );

      final accepted = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(accepted.accepted, isTrue);

      final restarted = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );
      final restored = await restarted.restore('runtime');
      expect(restored.isSuccess, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 1);

      final duplicate = await restarted.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'ignored',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.lastAcceptedClientSeq, 1);

      final stale = await restarted.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'ignored',
          clientEventId: 'p1-stale',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );
      expect(stale.rejected, isTrue);
      expect(stale.mustFullyResync, isTrue);
    });

    test('restore falls back on invalid snapshot and replays from sequence 0',
        () async {
      final store = InMemoryAuthorityStore();
      final initial = buildInitialMatch();
      final acceptedRecord = ServerEventRecord(
        clientEvent: const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
        outcome: ServerApplyStatus.accepted,
        authoritativeSequence: 1,
      );
      store.seedAcceptedEvents(
        'runtime',
        <PersistedAuthorityEvent>[
          PersistedAuthorityEvent.fromAcceptedRecord(
            engineVersion: initial.engineVersion,
            matchId: 'runtime',
            record: acceptedRecord,
          ),
        ],
      );
      store.seedSnapshot(
        'runtime',
        PersistedAuthoritySnapshot(
          schemaVersion: 1,
          engineVersion: initial.engineVersion,
          matchId: 'wrong',
          authoritativeSequence: 1,
          matchState: tryReduceMatch(
            initial,
            const JoinMatchEvent(playerId: 'p1'),
          ).state,
          matchFingerprint: 'invalid',
          recentClientEventIdsByPlayer: const <String, List<String>>{},
          lastAcceptedClientSeqByPlayer: const <String, int>{},
        ),
      );

      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: initial,
      );
      final restored = await runtime.restore('runtime');

      expect(restored.isSuccess, isTrue);
      expect(restored.usedSnapshotFallback, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 1);
    });

    test('restore fails on sequence gap in accepted tail', () async {
      final store = InMemoryAuthorityStore();
      final initial = buildInitialMatch();
      final accepted1 = PersistedAuthorityEvent.fromAcceptedRecord(
        engineVersion: initial.engineVersion,
        matchId: 'runtime',
        record: const ServerEventRecord(
          clientEvent: ClientEvent(
            matchId: 'runtime',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
          outcome: ServerApplyStatus.accepted,
          authoritativeSequence: 1,
        ),
      );
      final accepted3 = PersistedAuthorityEvent.fromAcceptedRecord(
        engineVersion: initial.engineVersion,
        matchId: 'runtime',
        record: const ServerEventRecord(
          clientEvent: ClientEvent(
            matchId: 'runtime',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: StartMatchEvent(),
          ),
          outcome: ServerApplyStatus.accepted,
          authoritativeSequence: 3,
        ),
      );
      store.seedAcceptedEvents('runtime', <PersistedAuthorityEvent>[
        accepted1,
        accepted3,
      ]);

      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: initial,
      );
      final restored = await runtime.restore('runtime');

      expect(restored.isSuccess, isFalse);
      expect(restored.failure?.code, AuthorityRestoreFailureCode.sequenceGap);
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

int _layoutStockCapacity() {
  final state = TriPeaksState.newGame(seed: 0);
  return 52 - state.tableau.length - 1;
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

Rank _expectedTierRandomRank({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required BonusSlotAnchorTier tier,
}) {
  const lowDomain = <Rank>[
    Rank.two,
    Rank.three,
    Rank.four,
    Rank.five,
    Rank.six,
    Rank.seven,
    Rank.eight,
    Rank.nine,
    Rank.ten,
  ];
  const highDomain = <Rank>[
    Rank.ace,
    Rank.jack,
    Rank.queen,
    Rank.king,
  ];
  final (tierDiscriminator, domain) = switch (tier) {
    BonusSlotAnchorTier.low => (1, lowDomain),
    BonusSlotAnchorTier.high => (2, highDomain),
  };
  final index = _expectedDeterministicIndex(
    roundSeed: roundSeed,
    spawnNonce: spawnNonce,
    slotIndex: slotIndex,
    tierDiscriminator: tierDiscriminator,
    domainSize: domain.length,
  );
  return domain[index];
}

int _expectedDeterministicIndex({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required int tierDiscriminator,
  required int domainSize,
}) {
  var x = 0x9e3779b9;
  x ^= roundSeed;
  x = _expectedMix32(x + 0x85ebca6b);
  x ^= (spawnNonce + 1) * 0x27d4eb2d;
  x = _expectedMix32(x);
  x ^= slotIndex * 0x165667b1;
  x = _expectedMix32(x + (tierDiscriminator * 0x9e3779b1));
  return (x & 0x7fffffff) % domainSize;
}

int _expectedMix32(int value) {
  var x = value & 0xffffffff;
  x ^= (x >> 16);
  x = (x * 0x7feb352d) & 0xffffffff;
  x ^= (x >> 15);
  x = (x * 0x846ca68b) & 0xffffffff;
  x ^= (x >> 16);
  return x & 0xffffffff;
}
