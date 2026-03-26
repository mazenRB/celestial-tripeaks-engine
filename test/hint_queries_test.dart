import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('Hint queries', () {
    test('playable moves and deterministic hint when moves exist', () {
      final deck = buildDeckWithBottomRow(
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

      final playable = getPlayableMoves(state, rules);
      final hint = getHint(state, rules, const HintConfig());

      expect(playable, equals(<int>[18, 19]));
      expect(hint.isSuccess, isTrue);
      expect(hint.moveIndex, 18);
    });

    test('no playable moves returns typed noHintAvailable', () {
      final deck = buildDeckWithBottomRow(
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
      final deck = buildDeckWithBottomRow(
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
}
