import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks session reducer - progression', () {
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
}
