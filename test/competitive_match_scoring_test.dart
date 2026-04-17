import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('Completed-run comparison helpers', () {
    CompletedSessionResult buildRun({
      required int seed,
      required int draws,
      required int roundsWon,
      CompletedRunStatus status = CompletedRunStatus.completed,
    }) {
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: seed,
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 10),
      );
      for (var i = 0; i < draws; i++) {
        session = tryReduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        ).state;
      }
      return CompletedSessionResult(
        schemaVersion: 1,
        engineVersion: 1,
        seed: seed,
        ruleset: session.ruleset,
        scoreConfig: session.scoreConfig,
        roundRulesConfig: session.roundRulesConfig,
        roundTimerConfig: session.roundTimerConfig,
        undoConfig: session.undoConfig,
        streakConfig: session.streakConfig,
        strikeTimerConfig: session.strikeTimerConfig,
        bonusSlotsConfig: session.bonusSlotsConfig,
        status: status,
        finalScore: session.cumulativeIncludingCurrentRoundScoreTotal,
        finalFingerprint: sessionFingerprint(session),
        roundsCompleted: roundsWon,
        roundsWon: roundsWon,
        roundsLost: 0,
        roundsTimedOut: 0,
        roundsAborted: 0,
      );
    }

    test('higher score ranks first under score policy', () {
      final result = compareCompletedRuns(
        <String, CompletedSessionResult>{
          'a': buildRun(seed: 999, draws: 1, roundsWon: 1),
          'b': buildRun(seed: 999, draws: 3, roundsWon: 1),
        },
      );

      expect(result.rankings.first.entryId, 'b');
      expect(result.rankings.first.breakdown.baseScore, 30);
    });

    test('winsThenScore prefers more wins before score', () {
      final result = compareCompletedRuns(
        <String, CompletedSessionResult>{
          'a': buildRun(seed: 999, draws: 3, roundsWon: 1),
          'b': buildRun(seed: 999, draws: 1, roundsWon: 2),
        },
        config: const CompetitionRankingConfig(
          tieBreakerPolicy: CompetitionTieBreakerPolicy.winsThenScore,
        ),
      );

      expect(result.rankings.first.entryId, 'b');
    });

    test('completed runs can receive completion and placement bonuses', () {
      final result = compareCompletedRuns(
        <String, CompletedSessionResult>{
          'a': buildRun(seed: 999, draws: 1, roundsWon: 1),
          'b': buildRun(seed: 999, draws: 3, roundsWon: 1),
        },
        config: const CompetitionRankingConfig(
          completionBonus: 25,
          placementBonuses: <int, int>{1: 50, 2: 10},
        ),
      );

      expect(result.rankings.first.entryId, 'b');
      expect(result.rankings.first.breakdown.completionBonus, 25);
      expect(result.rankings.first.breakdown.placementBonus, 50);
      expect(result.rankings.last.breakdown.placementBonus, 10);
    });
  });
}
