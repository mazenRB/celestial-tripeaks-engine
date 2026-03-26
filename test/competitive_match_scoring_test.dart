import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
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
}
