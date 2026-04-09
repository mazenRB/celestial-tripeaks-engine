import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Round timer', () {
    test('timed rounds require explicit start and advance deterministically',
        () {
      final initial = TriPeaksState.newGame(
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 5),
        roundTimerConfig: const RoundTimerConfig(
          enabled: true,
          durationsSecondsByRound: <int>[5],
        ),
      );

      expect(initial.isRoundTimerAwaitingStart, isTrue);
      expect(initial.isGameplayEnabled, isFalse);
      expect(initial.roundTimerState.remainingSeconds, 5);

      final blocked = tryReduceTriPeaks(
        initial,
        const DrawFromStockAction(),
      );
      expect(blocked.error?.code, TriPeaksErrorCode.roundTimerNotStarted);
      expect(blocked.scoreDelta, 0);

      final started = reduceTriPeaks(initial, const StartRoundTimerAction());
      expect(started.roundTimerState.isStarted, isTrue);
      expect(started.roundTimerState.deadlineToken, 1);
      expect(started.scoreState.totalScore, 0);
      expect(started.scoreState.lastDelta, 0);

      final afterDraw = reduceTriPeaks(started, const DrawFromStockAction());
      expect(afterDraw.scoreState.totalScore, 5);

      final advanced = reduceTriPeaks(
        afterDraw,
        const AdvanceRoundTimerAction(
          elapsedSeconds: 2,
          deadlineToken: 1,
        ),
      );
      expect(advanced.roundTimerState.remainingSeconds, 3);
      expect(advanced.roundTimerState.deadlineToken, 2);
      expect(advanced.isTimedOut, isFalse);
      expect(advanced.scoreState.totalScore, 5);
      expect(advanced.scoreState.lastDelta, 0);
      expect(
        advanced.scoreState.lastBreakdown.totalDelta,
        0,
      );

      final stale = tryReduceTriPeaks(
        advanced,
        const AdvanceRoundTimerAction(
          elapsedSeconds: 1,
          deadlineToken: 1,
        ),
      );
      expect(stale.error?.code, TriPeaksErrorCode.staleRoundTimerUpdate);

      final invalidElapsed = tryReduceTriPeaks(
        advanced,
        const AdvanceRoundTimerAction(
          elapsedSeconds: 0,
          deadlineToken: 2,
        ),
      );
      expect(
        invalidElapsed.error?.code,
        TriPeaksErrorCode.invalidRoundTimerElapsed,
      );
    });

    test('untimed rounds are playable immediately and reject timer actions',
        () {
      final initial = TriPeaksState.newGame(
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
        roundTimerConfig: const RoundTimerConfig(
          enabled: true,
          durationsSecondsByRound: <int>[0],
        ),
      );

      expect(initial.hasActiveRoundTimer, isFalse);
      expect(initial.isRoundTimerAwaitingStart, isFalse);
      expect(initial.isGameplayEnabled, isTrue);

      final startError = tryReduceTriPeaks(
        initial,
        const StartRoundTimerAction(),
      );
      expect(startError.error?.code, TriPeaksErrorCode.roundTimerDisabled);

      final advanceError = tryReduceTriPeaks(
        initial,
        const AdvanceRoundTimerAction(
          elapsedSeconds: 1,
          deadlineToken: 0,
        ),
      );
      expect(advanceError.error?.code, TriPeaksErrorCode.roundTimerDisabled);

      final played = reduceTriPeaks(initial, const DrawFromStockAction());
      expect(played.scoreState.totalScore, 1);
    });

    test('save and load preserve active timer state', () {
      var state = TriPeaksState.newGame(
        roundTimerConfig: const RoundTimerConfig(
          enabled: true,
          durationsSecondsByRound: <int>[4],
        ),
      );
      state = reduceTriPeaks(state, const StartRoundTimerAction());
      state = reduceTriPeaks(
        state,
        const AdvanceRoundTimerAction(
          elapsedSeconds: 1,
          deadlineToken: 1,
        ),
      );

      final save = encodeSaveRound(state, savedAtSequence: 2);
      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.state.roundTimerState.isStarted, isTrue);
      expect(decoded.value!.state.roundTimerState.remainingSeconds, 3);
      expect(decoded.value!.state.roundTimerState.deadlineToken, 2);
    });
  });

  group('Round timer session flow', () {
    test('session creation rejects mismatched timer schedule length', () {
      expect(
        () => TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          roundTimerConfig: const RoundTimerConfig(
            enabled: true,
            durationsSecondsByRound: <int>[5, 0],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('timeout finishes the round and records timedOut outcome', () {
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 5),
        roundTimerConfig: const RoundTimerConfig(
          enabled: true,
          durationsSecondsByRound: <int>[3, 0, 4],
        ),
      );

      session = reduceTriPeaksSession(
        session,
        const PlayRoundAction(StartRoundTimerAction()),
      );
      session = reduceTriPeaksSession(
        session,
        const PlayRoundAction(DrawFromStockAction()),
      );
      session = reduceTriPeaksSession(
        session,
        const PlayRoundAction(
          AdvanceRoundTimerAction(
            elapsedSeconds: 3,
            deadlineToken: 1,
          ),
        ),
      );

      expect(session.currentRound.isTimedOut, isTrue);
      expect(session.currentRound.scoreState.totalScore, 5);
      expect(session.currentRound.scoreState.lastDelta, 0);
      expect(session.currentRound.scoreState.lastBreakdown.totalDelta, 0);
      expect(session.roundsCompleted, 1);
      expect(session.roundsTimedOut, 1);
      expect(session.roundResults.single.outcome, RoundOutcome.timedOut);
      expect(session.roundResults.single.finalScore, 5);
      expect(session.status, TriPeaksSessionStatus.timedOut);

      final blocked = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(DrawFromStockAction()),
      );
      expect(
        blocked.sessionError?.code,
        TriPeaksSessionErrorCode.roundAlreadyFinished,
      );

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRoundNumber, 2);
      expect(session.currentRound.hasActiveRoundTimer, isFalse);
      expect(session.currentRound.isGameplayEnabled, isTrue);
    });

    test('ten-round schedules can assign a different timer per round', () {
      final schedule = List<int>.generate(10, (index) => index + 1);
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.tenRounds,
        roundTimerConfig: RoundTimerConfig(
          enabled: true,
          durationsSecondsByRound: schedule,
        ),
      );

      for (var round = 1; round <= 10; round++) {
        expect(session.currentRoundNumber, round);
        expect(session.currentRound.configuredRoundDurationSeconds, round);
        if (round < 10) {
          session = reduceTriPeaksSession(
            session,
            const AbortRoundAction(),
          );
        }
      }
    });
  });
}
