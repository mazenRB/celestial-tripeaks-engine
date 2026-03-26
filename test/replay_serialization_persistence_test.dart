import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Serialization', () {
    test('mode bundle round-trip preserves classic and celestial bundles', () {
      final classicDecoded = TriPeaksModeBundle.tryFromMap(
        TriPeaksModeBundle.classic.toMap(),
      );
      final celestialDecoded = TriPeaksModeBundle.tryFromMap(
        TriPeaksModeBundle.celestial.toMap(),
      );

      expect(classicDecoded.isSuccess, isTrue);
      expect(classicDecoded.value, TriPeaksModeBundle.classic);
      expect(celestialDecoded.isSuccess, isTrue);
      expect(celestialDecoded.value, TriPeaksModeBundle.celestial);
    });

    test('mode bundle decode preserves nested values without re-resolving', () {
      final map = TriPeaksModeBundle.celestial.toMap();
      final scoreConfig = Map<String, dynamic>.from(
        map['scoreConfig'] as Map<String, dynamic>,
      );
      scoreConfig['pointsDrawFromStock'] = 7;
      map['scoreConfig'] = scoreConfig;

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.preset, TriPeaksModePreset.celestial);
      expect(decoded.value!.scoreConfig.pointsDrawFromStock, 7);
      expect(
        decoded.value!.scoreConfig.pointsDrawFromStock,
        isNot(TriPeaksModeBundle.celestial.scoreConfig.pointsDrawFromStock),
      );
    });

    test('mode bundle decode rejects unknown preset id', () {
      final map = TriPeaksModeBundle.classic.toMap();
      map['presetId'] = 'unknown';

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('mode bundle decode rejects invalid nested payload', () {
      final map = TriPeaksModeBundle.classic.toMap();
      final scoreConfig = Map<String, dynamic>.from(
        map['scoreConfig'] as Map<String, dynamic>,
      );
      scoreConfig['pointsDrawFromStock'] = 'bad';
      map['scoreConfig'] = scoreConfig;

      final decoded = TriPeaksModeBundle.tryFromMap(map);

      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('round result finalScore is backward compatible', () {
      final legacy = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'won',
        },
      );
      expect(legacy.isSuccess, isTrue);
      expect(legacy.value!.finalScore, isNull);

      final current = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 2,
          'outcome': 'lost',
          'finalScore': 11,
        },
      );
      expect(current.isSuccess, isTrue);
      expect(current.value!.finalScore, 11);
    });

    test('round result decode rejects invalid finalScore type', () {
      final decoded = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'won',
          'finalScore': '11',
        },
      );
      expect(decoded.isSuccess, isFalse);
      expect(decoded.error?.code, DecodeFailureCode.invalidPayload);
    });

    test('bonus slots config round-trip supports stockTopCard', () {
      const config = BonusSlotsConfig(
        spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
      );
      final decoded = BonusSlotsConfig.tryFromMap(config.toMap());
      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.spawnPolicy, BonusSlotSpawnPolicy.stockTopCard);
    });

    test('bonus slots config map is stable (golden)', () {
      const config = BonusSlotsConfig(
        enabled: true,
        spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
        defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.high,
        lowTierAnchorRank: Rank.eight,
        highTierAnchorRank: Rank.king,
        jokerAcceptsAnyRank: false,
        jokerConsumedOnFirstUse: true,
        spawnOnOpenSlot2AtStreak: 3,
        spawnOnOpenSlot3AtStreak: 6,
        closeOnDraw: true,
        closeOnInvalidAction: true,
        maxSlots: 3,
      );
      expect(
        config.toMap(),
        equals(
          <String, dynamic>{
            'schemaVersion': 1,
            'type': 'bonus_slots_config',
            'enabled': true,
            'spawnPolicy': 'tierFixedRank',
            'defaultAnchorTierWhenUnknown': 'high',
            'lowTierAnchorRank': 'eight',
            'highTierAnchorRank': 'king',
            'jokerAcceptsAnyRank': false,
            'jokerConsumedOnFirstUse': true,
            'spawnOnOpenSlot2AtStreak': 3,
            'spawnOnOpenSlot3AtStreak': 6,
            'closeOnDraw': true,
            'closeOnInvalidAction': true,
            'maxSlots': 3,
          },
        ),
      );
    });

    test('anchor card map is stable (golden)', () {
      const anchor = Card.anchor(Rank.queen);
      expect(
        anchor.toMap(),
        equals(
          <String, dynamic>{
            'schemaVersion': 1,
            'type': 'card',
            'cardKind': 'anchor',
            'rank': 'queen',
          },
        ),
      );
    });

    test('round state map round-trip preserves deep state', () {
      final original = TriPeaksState.newGame(
        seed: 5,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
        undoConfig: const UndoConfig(maxSteps: 4),
      );
      final progressed = _applyTryActions(
        original,
        const <TriPeaksAction>[
          DrawFromStockAction(),
          DrawFromStockAction(),
          RemoveTableauCardAction(99),
        ],
      );

      final decoded = TriPeaksState.tryFromMap(
        progressed.toMap(),
      );
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;

      expect(restored.tableau, equals(progressed.tableau));
      expect(restored.removed, equals(progressed.removed));
      expect(restored.waste, equals(progressed.waste));
      expect(restored.stock, equals(progressed.stock));
      expect(restored.scoreConfig.penaltyInvalidAction, -3);
      expect(restored.scoreState.totalScore, progressed.scoreState.totalScore);
      expect(
        restored.streakState.currentStreak,
        progressed.streakState.currentStreak,
      );
      expect(restored.roundSeed, progressed.roundSeed);
      expect(restored.bonusAnchorSpawnNonce, progressed.bonusAnchorSpawnNonce);
      expect(restored.undoStepsAvailable, progressed.undoStepsAvailable);
    });

    test('tierFixedRank config and anchor card round-trip via map', () {
      var state = TriPeaksState.newGame(
        deck: _buildStreakUnlockDeck(),
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.high,
          lowTierAnchorRank: Rank.eight,
          highTierAnchorRank: Rank.king,
        ),
      );
      state = reduceTriPeaks(state, const RemoveTableauCardAction(18));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(19));
      state = reduceTriPeaks(state, const RemoveTableauCardAction(20));
      final before = stateFingerprint(state);

      final decoded = TriPeaksState.tryFromMap(state.toMap());
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;

      expect(restored.bonusSlotsConfig.spawnPolicy,
          BonusSlotSpawnPolicy.tierFixedRank);
      expect(
        restored.bonusSlotsConfig.defaultAnchorTierWhenUnknown,
        BonusSlotAnchorTier.high,
      );
      expect(restored.bonusSlotsConfig.lowTierAnchorRank, Rank.eight);
      expect(restored.bonusSlotsConfig.highTierAnchorRank, Rank.king);
      expect(restored.bonusSlotsState.slots[1].single.isAnchor, isTrue);
      expect(stateFingerprint(restored), before);
    });

    test('session action map round-trip preserves action identity', () {
      final actions = <TriPeaksSessionAction>[
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(RemoveTableauCardAction(12)),
        const PlayRoundAction(UndoAction()),
        const PlayRoundAction(StrikeTimerExpiredAction(deadlineToken: 7)),
        const StartNextRoundAction(),
        const AbortRoundAction(reason: AbortReason.disconnect),
      ];

      for (final action in actions) {
        final map = sessionActionToMap(action);
        final decodedEnvelope = decodeActionEnvelope(map);
        expect(decodedEnvelope.isSuccess, isTrue);
        final decoded = decodedEnvelope.value!.sessionAction!;

        expect(map['type'], 'tripeaks_session_action');
        switch ((action, decoded)) {
          case (
              PlayRoundAction(action: DrawFromStockAction()),
              PlayRoundAction(action: DrawFromStockAction())
            ):
            break;
          case (
              PlayRoundAction(action: RemoveTableauCardAction(index: final a)),
              PlayRoundAction(action: RemoveTableauCardAction(index: final b))
            ):
            expect(a, b);
            break;
          case (
              PlayRoundAction(action: UndoAction()),
              PlayRoundAction(action: UndoAction())
            ):
            break;
          case (
              PlayRoundAction(
                action: StrikeTimerExpiredAction(deadlineToken: final a),
              ),
              PlayRoundAction(
                action: StrikeTimerExpiredAction(deadlineToken: final b),
              )
            ):
            expect(a, b);
            break;
          case (StartNextRoundAction(), StartNextRoundAction()):
            break;
          case (
              AbortRoundAction(reason: final a),
              AbortRoundAction(reason: final b)
            ):
            expect(a, b);
            break;
          default:
            fail('Decoded action did not match original.');
        }
      }
    });

    test('decodeStateEnvelope returns typed failure for unsupported version',
        () {
      final result = decodeStateEnvelope(
        <String, dynamic>{
          'schemaVersion': 999,
          'type': 'tripeaks_round_state',
        },
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.error?.code,
        DecodeFailureCode.unsupportedSchemaVersion,
      );
    });

    test('replay map includes tierFixedRank bonus config deterministically',
        () {
      final replay = TriPeaksReplay.newSession(
        seed: 7,
        bonusSlotsConfig: const BonusSlotsConfig(
          spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.low,
          lowTierAnchorRank: Rank.six,
          highTierAnchorRank: Rank.queen,
        ),
      );
      final map = replay.toMap();
      final bonus = map['bonusSlotsConfig'] as Map<String, dynamic>;
      expect(bonus['spawnPolicy'], 'tierFixedRank');
      expect(bonus['defaultAnchorTierWhenUnknown'], 'low');
      expect(bonus['lowTierAnchorRank'], 'six');
      expect(bonus['highTierAnchorRank'], 'queen');
    });
  });

  group('Fingerprint', () {
    test('identical states produce identical fingerprint', () {
      final stateA = TriPeaksState.newGame(seed: 12);
      final stateB = TriPeaksState.newGame(seed: 12);

      expect(stateFingerprint(stateA), stateFingerprint(stateB));
    });

    test('small state change produces a different fingerprint', () {
      final state = TriPeaksState.newGame(seed: 12);
      final changed = reduceTriPeaks(state, const DrawFromStockAction());

      expect(stateFingerprint(state), isNot(stateFingerprint(changed)));
    });

    test('fingerprint is stable for fixed canonical state', () {
      final state = TriPeaksState.newGame(seed: 42);
      expect(stateFingerprint(state), '54f511b5');
    });
  });

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
