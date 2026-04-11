import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';
import 'package:test/test.dart';

void main() {
  group('Save/Load', () {
    test('tierFixedRank round save/load keeps anchor state and fingerprint',
        () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          lowTierAnchorRank: Rank.six,
          highTierAnchorRank: Rank.queen,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      expect(state.bonusSlotsState.slots[1].single.isAnchor, isTrue);

      final save = encodeSaveRound(state, savedAtSequence: 3);
      final loaded = decodeSaveRound(save);
      expect(loaded.isSuccess, isTrue);
      expect(
        loaded.value!.state.bonusSlotsState.slots[1].single.isAnchor,
        isTrue,
      );
      expect(
        stateFingerprint(loaded.value!.state),
        stateFingerprint(state),
      );
    });

    test('round save round-trip preserves state and fingerprint', () {
      final initial = TriPeaksState.newGame(
        seed: 17,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );
      final state = _applyTryActions(
        initial,
        const <TriPeaksAction>[
          DrawFromStockAction(),
          RemoveTableauCardAction(99),
          DrawFromStockAction(),
        ],
      );

      final save = encodeSaveRound(state, engineVersion: 1, savedAtSequence: 9);
      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isTrue);
      final value = decoded.value!;
      expect(value.savedAtSequence, 9);
      expect(value.engineVersion, 1);
      expect(value.fingerprint, stateFingerprint(state));
      expect(value.state.tableau, equals(state.tableau));
      expect(value.state.removed, equals(state.removed));
      expect(value.state.waste, equals(state.waste));
      expect(value.state.stock, equals(state.stock));
      expect(value.state.scoreState.totalScore, state.scoreState.totalScore);
    });

    test('corrupted round payload returns corruptSave failure', () {
      final state = TriPeaksState.newGame(seed: 17);
      final save = encodeSaveRound(state);
      final payload = save['payload'] as Map<String, dynamic>;
      final removed = (payload['removed'] as List<dynamic>).toList();
      removed[0] = !(removed[0] as bool);
      payload['removed'] = removed;

      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, SaveDecodeFailureCode.corruptSave);
    });

    test('unsupported save schemaVersion returns typed failure', () {
      final state = TriPeaksState.newGame(seed: 17);
      final save = encodeSaveRound(state);
      save['schemaVersion'] = 999;

      final decoded = decodeSaveRound(save);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, SaveDecodeFailureCode.unsupportedVersion);
    });
  });
}

List<Card> _buildDeck({
  required Map<int, Card> tableauOverrides,
  required Card waste,
}) {
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  for (final entry in tableauOverrides.entries) {
    _placeCard(deck, entry.key, entry.value);
  }
  return deck;
}

List<Card> _buildStreakUnlockDeck() {
  return _buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.three, Suit.clubs),
      22: const Card(Rank.two, Suit.clubs),
      23: const Card(Rank.ace, Suit.clubs),
      24: const Card(Rank.king, Suit.clubs),
      25: const Card(Rank.queen, Suit.clubs),
      26: const Card(Rank.jack, Suit.clubs),
      27: const Card(Rank.ten, Suit.clubs),
    },
  );
}

void _placeCard(List<Card> deck, int position, Card card) {
  final currentIndex = deck.indexOf(card);
  if (currentIndex == -1) {
    throw ArgumentError('Card $card is not present in standard deck.');
  }

  final temp = deck[position];
  deck[position] = deck[currentIndex];
  deck[currentIndex] = temp;
}

TriPeaksState _applyTryActions(
  TriPeaksState initial,
  List<TriPeaksAction> actions,
) {
  var state = initial;
  for (final action in actions) {
    state = tryReduceTriPeaks(state, action).state;
  }
  return state;
}
