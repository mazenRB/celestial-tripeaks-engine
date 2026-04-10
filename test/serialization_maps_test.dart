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

    test('score config round-trip preserves allowNegativeTotalScore', () {
      const config = ScoreConfig(
        penaltyInvalidAction: -3,
        allowNegativeTotalScore: false,
        resetTimeBonusOnInvalidPenalty: true,
      );

      final decoded = ScoreConfig.tryFromMap(config.toMap());

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.penaltyInvalidAction, -3);
      expect(decoded.value!.allowNegativeTotalScore, isFalse);
      expect(decoded.value!.resetTimeBonusOnInvalidPenalty, isTrue);
    });

    test('score config decode defaults missing allowNegativeTotalScore to true',
        () {
      final map = const ScoreConfig(
        penaltyInvalidAction: -3,
      ).toMap()
        ..remove('allowNegativeTotalScore');

      final decoded = ScoreConfig.tryFromMap(map);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.penaltyInvalidAction, -3);
      expect(decoded.value!.allowNegativeTotalScore, isTrue);
      expect(decoded.value!.resetTimeBonusOnInvalidPenalty, isFalse);
    });

    test(
        'score config decode defaults missing resetTimeBonusOnInvalidPenalty to false',
        () {
      final map = const ScoreConfig(
        penaltyInvalidAction: -3,
        resetTimeBonusOnInvalidPenalty: true,
      ).toMap()
        ..remove('resetTimeBonusOnInvalidPenalty');

      final decoded = ScoreConfig.tryFromMap(map);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.penaltyInvalidAction, -3);
      expect(decoded.value!.resetTimeBonusOnInvalidPenalty, isFalse);
    });

    test('round timer config round-trip preserves mixed schedule', () {
      const config = RoundTimerConfig(
        enabled: true,
        durationsSecondsByRound: <int>[9, 0, 7],
      );

      final decoded = RoundTimerConfig.tryFromMap(config.toMap());

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.enabled, isTrue);
      expect(
        decoded.value!.durationsSecondsByRound,
        equals(const <int>[9, 0, 7]),
      );
    });

    test('session decode defaults missing roundTimerConfig to disabled', () {
      final map = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 14,
      ).toMap()
        ..remove('roundTimerConfig');

      final decoded = TriPeaksSessionState.tryFromMap(map);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.roundTimerConfig.enabled, isFalse);
      expect(decoded.value!.currentRound.hasActiveRoundTimer, isFalse);
    });

    test('replay and match config round-trip preserve roundTimerConfig', () {
      const roundTimerConfig = RoundTimerConfig(
        enabled: true,
        durationsSecondsByRound: <int>[5, 0, 7],
      );
      const scoreConfig = ScoreConfig(
        penaltyInvalidAction: -3,
        resetTimeBonusOnInvalidPenalty: true,
      );
      final replay = ReplaySession.newSession(
        seed: 9,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: scoreConfig,
        roundTimerConfig: roundTimerConfig,
      );
      final replayDecoded = ReplaySession.tryFromMap(replay.toMap());
      expect(replayDecoded.isSuccess, isTrue);
      expect(
        replayDecoded.value!.roundTimerConfig.durationsSecondsByRound,
        equals(roundTimerConfig.durationsSecondsByRound),
      );
      expect(
        replayDecoded.value!.scoreConfig.resetTimeBonusOnInvalidPenalty,
        isTrue,
      );

      final matchConfig = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'match-1',
        matchSeed: 42,
        maxPlayers: 2,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: scoreConfig,
        roundTimerConfig: roundTimerConfig,
      );
      final matchDecoded = MatchConfig.tryFromMap(matchConfig.toMap());
      expect(matchDecoded.isSuccess, isTrue);
      expect(
        matchDecoded.value!.roundTimerConfig.durationsSecondsByRound,
        equals(roundTimerConfig.durationsSecondsByRound),
      );
      expect(
        matchDecoded.value!.scoreConfig.resetTimeBonusOnInvalidPenalty,
        isTrue,
      );
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
      expect(restored.scoreConfig.allowNegativeTotalScore, isTrue);
      expect(restored.scoreConfig.resetTimeBonusOnInvalidPenalty, isFalse);
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

      expect(
        restored.bonusSlotsConfig.spawnPolicy,
        BonusSlotSpawnPolicy.tierFixedRank,
      );
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
        const PlayRoundAction(StartRoundTimerAction()),
        const PlayRoundAction(
          AdvanceRoundTimerAction(
            elapsedSeconds: 2,
            deadlineToken: 7,
          ),
        ),
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
              PlayRoundAction(action: StartRoundTimerAction()),
              PlayRoundAction(action: StartRoundTimerAction())
            ):
            break;
          case (
              PlayRoundAction(
                action: AdvanceRoundTimerAction(
                  elapsedSeconds: final elapsedA,
                  deadlineToken: final tokenA,
                ),
              ),
              PlayRoundAction(
                action: AdvanceRoundTimerAction(
                  elapsedSeconds: final elapsedB,
                  deadlineToken: final tokenB,
                ),
              )
            ):
            expect(elapsedA, elapsedB);
            expect(tokenA, tokenB);
            break;
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
