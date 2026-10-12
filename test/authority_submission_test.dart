import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:celestial_tripeaks/tripeaks_authority.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';
import 'package:test/test.dart';

void main() {
  test('authority verifies complete replay against shared match seed', () {
    final config = MatchConfig(
      matchMode: MatchMode.asynchronous,
      matchId: 'async-verify',
      matchSeed: 42,
      playerIds: const <String>['p1', 'p2'],
      ruleset: TriPeaksRuleset.oneRound,
    );
    var session = TriPeaksSessionState.newSession(
      ruleset: config.ruleset,
      seed: config.matchSeed,
    );
    var replay = ReplaySession.newSession(
      seed: config.matchSeed,
      ruleset: config.ruleset,
    );
    final recorded = recordAction(
      replay,
      session,
      const AbortRoundAction(),
    );
    session = recorded.state;
    replay = recorded.replay;
    expect(session.isSessionFinished, isTrue);

    final verified = verifyMatchSubmission(
      config: config,
      playerId: 'p1',
      replay: replay,
    );
    expect(verified.isValid, isTrue);
    expect(verified.result!.finalScore,
        session.cumulativeFinishedRoundsScoreTotal);

    final wrongSeed =
        ReplaySession.newSession(seed: 43, ruleset: config.ruleset);
    final rejected = verifyMatchSubmission(
      config: config,
      playerId: 'p1',
      replay: wrongSeed,
    );
    expect(rejected.isValid, isFalse);

    final incomplete = verifyMatchSubmission(
      config: config,
      playerId: 'p1',
      replay: ReplaySession.newSession(seed: 42, ruleset: config.ruleset),
    );
    expect(incomplete.isValid, isFalse);
    expect(
      incomplete.failure!.code,
      MatchSubmissionFailureCode.sessionIncomplete,
    );

    final mismatch = verifyMatchSubmission(
      config: config.copyWith(
        scoreConfig: const ScoreConfig(pointsPeakCleared: 50),
      ),
      playerId: 'p1',
      replay: replay,
    );
    expect(mismatch.isValid, isFalse);
    expect(mismatch.failure!.code, MatchSubmissionFailureCode.rulesMismatch);
  });
}
