import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - time bonus', () {
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
  });
}
