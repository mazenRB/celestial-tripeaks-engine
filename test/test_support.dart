import 'package:celestial_tripeaks/tripeaks_engine.dart';

List<Card> buildDeck({
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

List<Card> buildPeakBonusDeck() {
  return buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      0: const Card(Rank.five, Suit.hearts),
      1: const Card(Rank.ten, Suit.spades),
      2: const Card(Rank.seven, Suit.diamonds),
      3: const Card(Rank.three, Suit.diamonds),
      4: const Card(Rank.four, Suit.spades),
      5: const Card(Rank.jack, Suit.diamonds),
      6: const Card(Rank.ten, Suit.hearts),
      7: const Card(Rank.eight, Suit.clubs),
      8: const Card(Rank.nine, Suit.diamonds),
      9: const Card(Rank.two, Suit.clubs),
      10: const Card(Rank.ace, Suit.diamonds),
      11: const Card(Rank.two, Suit.hearts),
      12: const Card(Rank.nine, Suit.clubs),
      13: const Card(Rank.ten, Suit.diamonds),
      14: const Card(Rank.jack, Suit.clubs),
      15: const Card(Rank.ten, Suit.clubs),
      16: const Card(Rank.jack, Suit.spades),
      17: const Card(Rank.queen, Suit.hearts),
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.diamonds),
      20: const Card(Rank.four, Suit.hearts),
      21: const Card(Rank.three, Suit.spades),
      22: const Card(Rank.six, Suit.diamonds),
      23: const Card(Rank.seven, Suit.clubs),
      24: const Card(Rank.eight, Suit.diamonds),
      25: const Card(Rank.jack, Suit.hearts),
      26: const Card(Rank.queen, Suit.clubs),
      27: const Card(Rank.king, Suit.diamonds),
    },
  );
}

List<Card> buildStreakUnlockDeck() {
  return buildDeck(
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

List<Card> buildBonusSlotTargetDeck() {
  final deck = buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.two, Suit.diamonds),
    },
  );
  _placeCard(deck, 29, const Card(Rank.three, Suit.hearts));
  return deck;
}

List<Card> buildJokerConsumeDeck() {
  return buildDeck(
    waste: const Card(Rank.seven, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.six, Suit.clubs),
      19: const Card(Rank.five, Suit.clubs),
      20: const Card(Rank.four, Suit.clubs),
      21: const Card(Rank.king, Suit.hearts),
    },
  );
}

List<Card> buildHighTierUnlockDeck() {
  return buildDeck(
    waste: const Card(Rank.queen, Suit.spades),
    tableauOverrides: <int, Card>{
      18: const Card(Rank.king, Suit.clubs),
      19: const Card(Rank.ace, Suit.clubs),
      20: const Card(Rank.king, Suit.hearts),
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

List<Card> buildAlwaysLostDeck({required Card waste}) {
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  _placeCard(deck, 51, const Card(Rank.ace, Suit.hearts));

  final exposedCandidates = deck
      .where(
        (card) =>
            card.rank != Rank.two &&
            card.rank != Rank.king &&
            card != waste &&
            card != const Card(Rank.ace, Suit.hearts),
      )
      .take(10)
      .toList();
  for (var i = 0; i < exposedCandidates.length; i++) {
    _placeCard(deck, 18 + i, exposedCandidates[i]);
  }

  return deck;
}

List<Card> buildDeckWithBottomRow({
  required Card waste,
  required List<Card> bottomRow,
}) {
  if (bottomRow.length != 10) {
    throw ArgumentError.value(
        bottomRow.length, 'bottomRow.length', 'Must be 10');
  }
  final deck = Card.standardDeck();
  _placeCard(deck, 28, waste);
  for (var i = 0; i < bottomRow.length; i++) {
    _placeCard(deck, 18 + i, bottomRow[i]);
  }
  return deck;
}

int layoutStockCapacity() {
  final state = TriPeaksState.newGame(seed: 0);
  return 52 - state.tableau.length - 1;
}

TriPeaksState applyTryActions(
  TriPeaksState initial,
  List<TriPeaksAction> actions,
) {
  var state = initial;
  for (final action in actions) {
    state = tryReduceTriPeaks(state, action).state;
  }
  return state;
}

MatchScoreState applyMatchEvents(
  MatchScoreState initial,
  List<MatchScoreEvent> events,
) {
  var state = initial;
  for (final event in events) {
    state = reduceMatchScore(state, event);
  }
  return state;
}

Rank expectedTierRandomRank({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required BonusSlotAnchorTier tier,
}) {
  const lowDomain = <Rank>[
    Rank.two,
    Rank.three,
    Rank.four,
    Rank.five,
    Rank.six,
    Rank.seven,
    Rank.eight,
    Rank.nine,
    Rank.ten,
  ];
  const highDomain = <Rank>[
    Rank.ace,
    Rank.jack,
    Rank.queen,
    Rank.king,
  ];
  final (tierDiscriminator, domain) = switch (tier) {
    BonusSlotAnchorTier.low => (1, lowDomain),
    BonusSlotAnchorTier.high => (2, highDomain),
  };
  final index = _expectedDeterministicIndex(
    roundSeed: roundSeed,
    spawnNonce: spawnNonce,
    slotIndex: slotIndex,
    tierDiscriminator: tierDiscriminator,
    domainSize: domain.length,
  );
  return domain[index];
}

int _expectedDeterministicIndex({
  required int roundSeed,
  required int spawnNonce,
  required int slotIndex,
  required int tierDiscriminator,
  required int domainSize,
}) {
  var x = 0x9e3779b9;
  x ^= roundSeed;
  x = _expectedMix32(x + 0x85ebca6b);
  x ^= (spawnNonce + 1) * 0x27d4eb2d;
  x = _expectedMix32(x);
  x ^= slotIndex * 0x165667b1;
  x = _expectedMix32(x + (tierDiscriminator * 0x9e3779b1));
  return (x & 0x7fffffff) % domainSize;
}

int _expectedMix32(int value) {
  var x = value & 0xffffffff;
  x ^= (x >> 16);
  x = (x * 0x7feb352d) & 0xffffffff;
  x ^= (x >> 15);
  x = (x * 0x846ca68b) & 0xffffffff;
  x ^= (x >> 16);
  return x & 0xffffffff;
}
