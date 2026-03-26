import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Match scoring layer', () {
    test('round score is unaffected by multiplayer bonuses', () {
      final deck = buildDeck(
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

      final finalA = applyMatchEvents(initialA, events);
      final finalB = applyMatchEvents(initialB, events);

      expect(finalA.totalScoresByPlayer, equals(finalB.totalScoresByPlayer));
      expect(finalA.processedEventsCount, finalB.processedEventsCount);
      expect(finalA.firstFinishAwardedTo, finalB.firstFinishAwardedTo);
    });
  });
}
