import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks session reducer', () {
    test('supports 1, 3, 6, and 10 rounds via ruleset', () {
      final one = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.oneRound,
        seed: 1,
      );
      final three = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 1,
      );
      final six = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.sixRounds,
        seed: 1,
      );
      final ten = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.tenRounds,
        seed: 1,
      );

      expect(one.ruleset.roundsPerGame, 1);
      expect(three.ruleset.roundsPerGame, 3);
      expect(six.ruleset.roundsPerGame, 6);
      expect(ten.ruleset.roundsPerGame, 10);
    });

    test('uses deterministic default seed for sessions', () {
      final sessionA = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );
      final sessionB = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );

      expect(
          sessionA.currentRound.tableau, equals(sessionB.currentRound.tableau));
      expect(sessionA.currentRound.waste, equals(sessionB.currentRound.waste));
      expect(sessionA.currentRound.stock, equals(sessionB.currentRound.stock));
    });

    test('can advance to next round after finishing current round', () {
      final fullStockSize = layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
      final round1Deck = buildAlwaysLostDeck(
        waste: const Card(Rank.ace, Suit.clubs),
      );
      final round2Deck = buildAlwaysLostDeck(
        waste: const Card(Rank.king, Suit.diamonds),
      );
      final round3Deck = buildAlwaysLostDeck(
        waste: const Card(Rank.queen, Suit.hearts),
      );

      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundRulesConfig: roundRules,
        roundDecks: <List<Card>>[
          round1Deck,
          round2Deck,
          round3Deck,
        ],
      );

      // Exhaust stock to force round 1 loss.
      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.currentRound.isLost, isTrue);
      expect(session.roundsCompleted, 1);
      expect(session.roundsLost, 1);
      expect(session.roundResults.last.outcome, RoundOutcome.lost);
      expect(
        session.roundResults.last.finalScore,
        session.currentRound.scoreState.totalScore,
      );
      expect(
        session.cumulativeFinishedRoundsScoreTotal,
        session.roundResults.last.finalScore,
      );
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.cumulativeFinishedRoundsScoreTotal,
      );

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRoundNumber, 2);
      expect(session.roundsCompleted, 1);
      expect(
        session.cumulativeFinishedRoundsScoreTotal,
        session.roundResults.first.finalScore,
      );
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.cumulativeFinishedRoundsScoreTotal +
            session.currentRound.scoreState.totalScore,
      );
    });

    test('cannot start next round before current round finishes', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 2,
      );

      final result = tryReduceTriPeaksSession(
        session,
        const StartNextRoundAction(),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.sessionError?.code,
        TriPeaksSessionErrorCode.roundNotFinished,
      );
    });

    test('session decode derives missing roundSeed from session seed + index',
        () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 40,
      );
      final map = session.toMap();
      final currentRound = map['currentRound'] as Map<String, dynamic>;
      currentRound.remove('roundSeed');

      final decoded = TriPeaksSessionState.tryFromMap(map);
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;
      expect(restored.currentRound.roundSeed, 40);
    });

    test('session status helper transitions deterministically', () {
      final fullStockSize = layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: <List<Card>>[
          buildAlwaysLostDeck(
            waste: const Card(Rank.ace, Suit.clubs),
          ),
          buildAlwaysLostDeck(
            waste: const Card(Rank.king, Suit.clubs),
          ),
          buildAlwaysLostDeck(
            waste: const Card(Rank.queen, Suit.clubs),
          ),
        ],
        roundRulesConfig: roundRules,
      );
      expect(session.status, TriPeaksSessionStatus.inProgress);

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.currentRound.isLost, isTrue);
      expect(session.status, TriPeaksSessionStatus.lost);

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.status, TriPeaksSessionStatus.inProgress);

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.status, TriPeaksSessionStatus.lost);

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      expect(session.isSessionFinished, isTrue);
      expect(session.status, TriPeaksSessionStatus.gameOver);
    });

    test('session uses configured invalid-action penalty', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 13,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );

      final result = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(RemoveTableauCardAction(99)),
      );

      expect(result.isSuccess, isFalse);
      expect(result.roundError?.code, TriPeaksErrorCode.invalidTableauIndex);
      expect(result.state.currentRound.scoreState.totalScore, -3);
      expect(result.state.currentRound.scoreState.lastDelta, -3);
      expect(result.state.currentRound.scoreState.movesCount, 1);
    });

    test('abort active round records aborted result and advances', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 17,
      );
      final expectedRoundTwo = TriPeaksState.newGame(
        seed: 18,
        roundNumber: 2,
        roundRulesConfig: session.roundRulesConfig,
      );

      final next = reduceTriPeaksSession(
        session,
        const AbortRoundAction(reason: AbortReason.userQuit),
      );

      expect(next.currentRoundNumber, 2);
      expect(next.roundsCompleted, 1);
      expect(next.roundsAborted, 1);
      expect(next.roundsWon, 0);
      expect(next.roundsLost, 0);
      expect(next.roundResults, hasLength(1));
      expect(next.roundResults.single.outcome, RoundOutcome.aborted);
      expect(next.roundResults.single.abortReason, AbortReason.userQuit);
      expect(next.roundResults.single.finalScore, 0);
      expect(next.currentRound.tableau, equals(expectedRoundTwo.tableau));
      expect(next.currentRound.waste, equals(expectedRoundTwo.waste));
      expect(next.currentRound.stock, equals(expectedRoundTwo.stock));
    });

    test('cumulative totals are deterministic and avoid double counting', () {
      final fullStockSize = layoutStockCapacity();
      final roundRules = RoundRulesConfig(
        startStockSize: fullStockSize,
        stockDecreaseEveryRounds: 100,
        minStockSize: fullStockSize,
      );
      var session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        roundDecks: <List<Card>>[
          buildAlwaysLostDeck(
            waste: const Card(Rank.ace, Suit.clubs),
          ),
          buildAlwaysLostDeck(
            waste: const Card(Rank.king, Suit.clubs),
          ),
          buildAlwaysLostDeck(
            waste: const Card(Rank.queen, Suit.clubs),
          ),
        ],
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
        roundRulesConfig: roundRules,
      );

      session = reduceTriPeaksSession(
        session,
        const PlayRoundAction(DrawFromStockAction()),
      );
      expect(session.isCurrentRoundFinished, isFalse);
      expect(session.cumulativeFinishedRoundsScoreTotal, 0);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        session.currentRound.scoreState.totalScore,
      );

      while (session.currentRound.canDrawFromStock) {
        session = reduceTriPeaksSession(
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
      }
      final finishedRoundOneScore = session.currentRound.scoreState.totalScore;
      expect(session.isCurrentRoundFinished, isTrue);
      expect(session.roundResults.last.finalScore, finishedRoundOneScore);
      expect(session.cumulativeFinishedRoundsScoreTotal, finishedRoundOneScore);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        finishedRoundOneScore,
      );

      session = reduceTriPeaksSession(session, const StartNextRoundAction());
      expect(session.currentRound.scoreState.totalScore, 0);
      expect(session.cumulativeFinishedRoundsScoreTotal, finishedRoundOneScore);
      expect(
        session.cumulativeIncludingCurrentRoundScoreTotal,
        finishedRoundOneScore,
      );
    });

    test('null finalScore values are skipped by cumulative finished total', () {
      final decode = RoundResult.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'lost',
        },
      );
      expect(decode.isSuccess, isTrue);
      expect(decode.value!.finalScore, isNull);

      final baseSession = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 99,
      );
      final map = baseSession.toMap();
      map['roundResults'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 1,
          'outcome': 'lost',
        },
        <String, dynamic>{
          'schemaVersion': 1,
          'type': 'round_result',
          'roundNumber': 2,
          'outcome': 'aborted',
          'abortReason': 'userSkip',
          'finalScore': 7,
        },
      ];
      final rebuilt = TriPeaksSessionState.tryFromMap(map);
      expect(rebuilt.isSuccess, isTrue);
      final withLegacyResult = rebuilt.value!;

      expect(withLegacyResult.cumulativeFinishedRoundsScoreTotal, 7);
    });

    test('abort on last round finishes session', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 30,
      );

      final afterFirstAbort = reduceTriPeaksSession(
        session,
        const AbortRoundAction(),
      );
      final afterSecondAbort = reduceTriPeaksSession(
        afterFirstAbort,
        const AbortRoundAction(),
      );
      final afterThirdAbort = reduceTriPeaksSession(
        afterSecondAbort,
        const AbortRoundAction(reason: AbortReason.disconnect),
      );

      expect(afterThirdAbort.isSessionFinished, isTrue);
      expect(afterThirdAbort.roundsCompleted, 3);
      expect(afterThirdAbort.roundsAborted, 3);
      expect(afterThirdAbort.roundResults, hasLength(3));
      expect(afterThirdAbort.roundResults.last.outcome, RoundOutcome.aborted);
      expect(
        afterThirdAbort.roundResults.last.abortReason,
        AbortReason.disconnect,
      );
    });

    test('abort when session finished returns typed failure', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 77,
      );
      final done = reduceTriPeaksSession(
        reduceTriPeaksSession(
          reduceTriPeaksSession(session, const AbortRoundAction()),
          const AbortRoundAction(),
        ),
        const AbortRoundAction(),
      );
      expect(done.isSessionFinished, isTrue);

      final result = tryReduceTriPeaksSession(done, const AbortRoundAction());

      expect(result.isSuccess, isFalse);
      expect(
        result.sessionError?.code,
        TriPeaksSessionErrorCode.gameAlreadyFinished,
      );
      expect(result.state, same(done));
    });
  });

  group('Hint queries', () {
    test('playable moves and deterministic hint when moves exist', () {
      final deck = buildDeckWithBottomRow(
        waste: const Card(Rank.seven, Suit.hearts),
        bottomRow: const <Card>[
          Card(Rank.six, Suit.clubs), // 18 playable
          Card(Rank.eight, Suit.clubs), // 19 playable
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
