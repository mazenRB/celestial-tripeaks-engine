import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
  group('async multiplayer matches', () {
    MatchConfig config({int? deadline = 604800}) => MatchConfig(
          matchMode: MatchMode.asynchronous,
          matchId: 'async-1',
          matchSeed: 987,
          playerIds: const <String>['p1', 'p2'],
          ruleset: TriPeaksRuleset.threeRounds,
          asyncDeadlineSeconds: deadline,
        );

    test('requires exactly two participants', () {
      expect(
        () => MatchState.newMatch(
          config: config().copyWith(
            playerIds: const <String>['p1', 'p2', 'p3'],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('finishes after both independent full-game results are submitted', () {
      var match = MatchState.newMatch(config: config());
      final p1Initial = match.players[0].session.currentRound.tableau;
      final p2Initial = match.players[1].session.currentRound.tableau;
      expect(p1Initial, equals(p2Initial));

      for (final playerId in const <String>['p1', 'p2']) {
        for (var round = 0; round < 3; round++) {
          final reduced = tryReduceMatch(
            match,
            SubmitMatchActionEvent(
              playerId: playerId,
              action: const AbortRoundAction(),
            ),
          );
          expect(reduced.isSuccess, isTrue);
          match = reduced.state;
        }
        if (playerId == 'p1') {
          expect(match.phase, MatchPhase.playing);
          expect(match.players[0].session.isSessionFinished, isTrue);
          expect(match.players[1].session.roundsCompleted, 0);
        }
      }

      expect(match.phase, MatchPhase.finished);
      expect(match.players.every((player) => player.session.isSessionFinished),
          isTrue);
      expect(
        match.players[0].session.cumulativeFinishedRoundsScoreTotal,
        match.players[1].session.cumulativeFinishedRoundsScoreTotal,
      );
      expect(match.result!.totalScores, <String, int>{'p1': 0, 'p2': 0});
      expect(match.result!.scoresForRound(1), <String, int>{'p1': 0, 'p2': 0});
      expect(
        MatchResult.tryFromMap(match.result!.toMap()).value!.toMap(),
        match.result!.toMap(),
      );
    });

    test('deadline can be disabled or explicitly expired', () {
      final noDeadline = MatchState.newMatch(config: config(deadline: null));
      expect(noDeadline.asyncDeadlineRemainingSeconds, isNull);

      final timed = MatchState.newMatch(config: config());
      final partial = tryReduceMatch(
        timed,
        AdvanceAsyncDeadlineEvent(
          elapsedSeconds: 604799,
          deadlineToken: timed.asyncDeadlineToken,
        ),
      );
      expect(partial.isSuccess, isTrue);
      expect(partial.state.asyncDeadlineRemainingSeconds, 1);
      final stale = tryReduceMatch(
        partial.state,
        AdvanceAsyncDeadlineEvent(
          elapsedSeconds: 1,
          deadlineToken: timed.asyncDeadlineToken,
        ),
      );
      expect(stale.isSuccess, isFalse);

      final expired = tryReduceMatch(
        partial.state,
        AdvanceAsyncDeadlineEvent(
          elapsedSeconds: 1,
          deadlineToken: partial.state.asyncDeadlineToken,
        ),
      );
      expect(expired.isSuccess, isTrue);
      expect(expired.state.phase, MatchPhase.finished);
      expect(expired.state.finishedByDeadline, isTrue);
    });

    test('participant withdrawal closes Async and appears in result data', () {
      final match = MatchState.newMatch(config: config());
      final withdrawn = tryReduceMatch(
        match,
        const WithdrawFromAsyncMatchEvent(playerId: 'p2'),
      );

      expect(withdrawn.isSuccess, isTrue);
      expect(withdrawn.state.phase, MatchPhase.finished);
      expect(withdrawn.state.result!.players.last.withdrew, isTrue);
      expect(withdrawn.state.result!.players.last.isComplete, isFalse);
    });
  });
}
