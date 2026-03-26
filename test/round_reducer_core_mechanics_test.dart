import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - core mechanics and stock', () {
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
  });
}
