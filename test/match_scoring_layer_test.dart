import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_helpers.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Competition score helpers', () {
    test('round score is unaffected by helper bonuses', () {
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

      var helper = const CompetitionScoreState(
        config: CompetitionScoreConfig(completionBonus: 10),
      );
      helper = reduceCompetitionScore(
        helper,
        RunScoreRecorded(
          entryId: 'p1',
          runScore: roundState.scoreState.totalScore,
        ),
      );
      helper = reduceCompetitionScore(
        helper,
        const BonusApplied(entryId: 'p1'),
      );

      expect(roundState.scoreState.totalScore, beforeRoundScore);
      expect(roundState.scoreState.totalScore, 5);
      expect(helper.totalFor('p1'), 15);
    });

    test('applies completion bonus to helper score', () {
      var helper = const CompetitionScoreState(
        config: CompetitionScoreConfig(completionBonus: 12),
      );

      helper = reduceCompetitionScore(
        helper,
        const RunScoreRecorded(entryId: 'p1', runScore: 9),
      );
      helper = reduceCompetitionScore(
        helper,
        const BonusApplied(entryId: 'p1'),
      );

      expect(helper.totalFor('p1'), 21);
      expect(helper.completionBonusAwardedTo, contains('p1'));
    });

    test('determinism: identical event sequence gives identical totals', () {
      final initialA = const CompetitionScoreState(
        config: CompetitionScoreConfig(
          completionBonus: 15,
          placementAdjustments: <int, int>{1: 7, 2: 2},
        ),
      );
      final initialB = const CompetitionScoreState(
        config: CompetitionScoreConfig(
          completionBonus: 15,
          placementAdjustments: <int, int>{1: 7, 2: 2},
        ),
      );
      final events = <CompetitionScoreEvent>[
        const RunScoreRecorded(entryId: 'p1', runScore: 11),
        const RunScoreRecorded(entryId: 'p2', runScore: 8),
        const BonusApplied(entryId: 'p1'),
        const PlacementAdjustmentApplied(entryId: 'p1', rank: 1),
        const PlacementAdjustmentApplied(entryId: 'p2', rank: 2),
      ];

      final finalA = applyCompetitionEvents(initialA, events);
      final finalB = applyCompetitionEvents(initialB, events);

      expect(finalA.totalScoresByEntry, equals(finalB.totalScoresByEntry));
      expect(finalA.processedEventsCount, finalB.processedEventsCount);
      expect(
        finalA.completionBonusAwardedTo,
        equals(finalB.completionBonusAwardedTo),
      );
    });
  });
}
