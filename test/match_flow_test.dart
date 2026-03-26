import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Deal policy', () {
    test('random mode returns deal on first attempt', () {
      final result = newGameWithDealPolicy(
        123,
        dealPolicy: const DealPolicyConfig(mode: DealPolicyMode.random),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state, isNotNull);
      expect(result.attemptCount, 1);
      expect(result.attemptSeed, 123);
    });

    test(
      'requireSolvable returns solvable deal or typed failure within maxAttempts',
      () {
        const policy = DealPolicyConfig(
          mode: DealPolicyMode.requireSolvable,
          maxAttempts: 5,
          solverNodeLimit: 50000,
        );
        final result = newGameWithDealPolicy(123, dealPolicy: policy);

        if (result.isSuccess) {
          expect(result.state, isNotNull);
          expect(isDealSolvable(result.state!), isTrue);
          expect(result.attemptCount!, inInclusiveRange(1, policy.maxAttempts));
        } else {
          expect(result.failure?.code, DealFailureCode.noSolvableDealFound);
        }
      },
    );

    test('same inputs produce same selected deal for requireSolvable', () {
      const policy = DealPolicyConfig(
        mode: DealPolicyMode.requireSolvable,
        maxAttempts: 20,
        attemptSeedStrategy: AttemptSeedStrategy.fnv1aMix,
        solverNodeLimit: 70000,
      );
      final a = newGameWithDealPolicy(777, dealPolicy: policy);
      final b = newGameWithDealPolicy(777, dealPolicy: policy);

      expect(a.isSuccess, b.isSuccess);
      if (!a.isSuccess) {
        expect(a.failure?.code, b.failure?.code);
        return;
      }
      expect(a.attemptSeed, b.attemptSeed);
      expect(a.attemptCount, b.attemptCount);
      expect(a.state!.tableau, equals(b.state!.tableau));
      expect(a.state!.waste, equals(b.state!.waste));
      expect(a.state!.stock, equals(b.state!.stock));
    });
  });

  group('Multiplayer match', () {
    MatchState buildInitialMatch() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'm1',
        matchSeed: 12345,
        maxPlayers: 4,
        ruleset: TriPeaksRuleset.threeRounds,
        dealPolicyConfig: const DealPolicyConfig(mode: DealPolicyMode.random),
      );
      return MatchState.newMatch(config: config);
    }

    test('players get identical initial deals with same matchSeed', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(
        match,
        const JoinMatchEvent(playerId: 'p1'),
      ).state;
      match = tryReduceMatch(
        match,
        const JoinMatchEvent(playerId: 'p2'),
      ).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final p1 = match.players.firstWhere((player) => player.playerId == 'p1');
      final p2 = match.players.firstWhere((player) => player.playerId == 'p2');

      expect(p1.session, isNotNull);
      expect(p2.session, isNotNull);
      expect(
        p1.session!.currentRound.tableau,
        equals(p2.session!.currentRound.tableau),
      );
      expect(p1.session!.currentRound.waste,
          equals(p2.session!.currentRound.waste));
      expect(p1.session!.currentRound.stock,
          equals(p2.session!.currentRound.stock));
    });

    test('submit action affects only submitting player state and replay', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p2')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final beforeP1 =
          match.players.firstWhere((player) => player.playerId == 'p1');
      final beforeP2 =
          match.players.firstWhere((player) => player.playerId == 'p2');

      final reduced = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
      );
      expect(reduced.isSuccess, isTrue);
      final after = reduced.state;
      final afterP1 =
          after.players.firstWhere((player) => player.playerId == 'p1');
      final afterP2 =
          after.players.firstWhere((player) => player.playerId == 'p2');

      expect(
        afterP1.session!.currentRound.stockCount,
        beforeP1.session!.currentRound.stockCount - 1,
      );
      expect(
        afterP2.session!.currentRound.stockCount,
        beforeP2.session!.currentRound.stockCount,
      );
      expect(
          afterP1.replay!.entries.length, beforeP1.replay!.entries.length + 1);
      expect(afterP2.replay!.entries.length, beforeP2.replay!.entries.length);
    });

    test('rejected actions do not change player state but are recorded', () {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'm2',
        matchSeed: 456,
        maxPlayers: 2,
        undoConfig: const UndoConfig(enabled: false),
      );
      var match = MatchState.newMatch(config: config);
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      final before = match.players.single;
      final reduced = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(UndoAction()),
        ),
      );
      expect(reduced.isSuccess, isTrue);
      final after = reduced.state.players.single;

      expect(
        after.session!.currentRound.stock,
        equals(before.session!.currentRound.stock),
      );
      expect(
        after.session!.currentRound.waste,
        equals(before.session!.currentRound.waste),
      );
      expect(after.replay!.entries.length, before.replay!.entries.length + 1);
      expect(after.replay!.entries.last.accepted, isFalse);
      expect(
        after.replay!.entries.last.failureReason,
        ReplayFailureReason.undoDisabled,
      );
    });

    test('finish order is deterministic and follows event ordering', () {
      var match = buildInitialMatch();
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p1')).state;
      match = tryReduceMatch(match, const JoinMatchEvent(playerId: 'p2')).state;
      match = tryReduceMatch(match, const StartMatchEvent()).state;

      for (var i = 0; i < 3; i++) {
        match = tryReduceMatch(
          match,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        match = tryReduceMatch(
          match,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final p1 = match.players.firstWhere((player) => player.playerId == 'p1');
      final p2 = match.players.firstWhere((player) => player.playerId == 'p2');
      expect(p1.status, PlayerStatus.finished);
      expect(p2.status, PlayerStatus.finished);
      expect(p1.finishOrderIndex, 1);
      expect(p2.finishOrderIndex, 2);
    });

    test('replaying ordered events reproduces exact same final match state',
        () {
      final initial = buildInitialMatch();
      final events = <MatchEvent>[
        const JoinMatchEvent(playerId: 'p1'),
        const JoinMatchEvent(playerId: 'p2'),
        const StartMatchEvent(),
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(RemoveTableauCardAction(99)),
        ),
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: PlayRoundAction(RemoveTableauCardAction(99)),
        ),
      ];

      var live = initial;
      for (final event in events) {
        live = tryReduceMatch(live, event).state;
      }
      final replayed = replayMatchEvents(initial, events);

      expect(replayed.toMap(), equals(live.toMap()));
    });
  });

  group('Competitive match scoring', () {
    MatchState buildStartedMatch({
      ScoreConfig scoreConfig = const ScoreConfig(),
    }) {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'comp',
        matchSeed: 999,
        maxPlayers: 2,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: scoreConfig,
        dealPolicyConfig: const DealPolicyConfig(mode: DealPolicyMode.random),
      );
      var state = MatchState.newMatch(config: config);
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p1')).state;
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p2')).state;
      state = tryReduceMatch(state, const StartMatchEvent()).state;
      return state;
    }

    test('first finisher receives configured firstFinishBonus', () {
      var state = buildStartedMatch();

      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final result = computeMatchResults(
        state,
        const MatchScoringConfig(firstFinishBonus: 100),
      );
      final p1 = result.placements.firstWhere((p) => p.playerId == 'p1');
      final p2 = result.placements.firstWhere((p) => p.playerId == 'p2');

      expect(p1.breakdown.firstFinishBonus, 100);
      expect(p2.breakdown.firstFinishBonus, 0);
    });

    test('tie resolution follows tieBreakerPolicy', () {
      var state = buildStartedMatch(
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
      );

      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }

      final finishOrderResult = computeMatchResults(
        state,
        const MatchScoringConfig(
          tieBreakerPolicy: MatchTieBreakerPolicy.finishOrder,
        ),
      );
      final scoreResult = computeMatchResults(
        state,
        const MatchScoringConfig(
          tieBreakerPolicy: MatchTieBreakerPolicy.score,
        ),
      );

      expect(finishOrderResult.placements.first.playerId, 'p1');
      expect(scoreResult.placements.first.playerId, 'p2');
    });

    test(
      'players with same finish order are ranked by score when policy uses score',
      () {
        var state = buildStartedMatch(
          scoreConfig: const ScoreConfig(pointsDrawFromStock: 1),
        );

        // Both remain unfinished (finishOrderIndex null), scores diverge.
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).state;

        final finishOrderResult = computeMatchResults(
          state,
          const MatchScoringConfig(
            tieBreakerPolicy: MatchTieBreakerPolicy.finishOrder,
          ),
        );
        final scoreResult = computeMatchResults(
          state,
          const MatchScoringConfig(
            tieBreakerPolicy: MatchTieBreakerPolicy.score,
          ),
        );

        expect(finishOrderResult.placements.first.playerId, 'p1');
        expect(scoreResult.placements.first.playerId, 'p2');
      },
    );
  });

  group('Match finalization', () {
    MatchState buildFinalizableMatch() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'fin',
        matchSeed: 1001,
        maxPlayers: 2,
      );
      var state = MatchState.newMatch(config: config);
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p1')).state;
      state = tryReduceMatch(state, const JoinMatchEvent(playerId: 'p2')).state;
      state = tryReduceMatch(state, const StartMatchEvent()).state;
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      for (var i = 0; i < 3; i++) {
        state = tryReduceMatch(
          state,
          const SubmitMatchActionEvent(
            playerId: 'p2',
            action: AbortRoundAction(reason: AbortReason.userSkip),
          ),
        ).state;
      }
      return state;
    }

    test('finalizeMatch produces stable result for same match state', () {
      final state = buildFinalizableMatch();
      const config = MatchFinalizationConfig(
        finishCondition: MatchFinishCondition.allPlayersFinished,
      );

      final a = finalizeMatch(state, config);
      final b = finalizeMatch(state, config);

      expect(a.isSuccess, isTrue);
      expect(b.isSuccess, isTrue);
      expect(a.result!.toMap(), equals(b.result!.toMap()));
    });

    test('finalized match rejects further submit actions', () {
      final state = buildFinalizableMatch();
      final finalized = finalizeMatch(
        state,
        const MatchFinalizationConfig(
          finishCondition: MatchFinishCondition.allPlayersFinished,
        ),
      );
      expect(finalized.isSuccess, isTrue);
      final finishedState = finalized.finishedMatchState!;

      final after = tryReduceMatch(
        finishedState,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
      );
      expect(after.isSuccess, isFalse);
      expect(after.failure?.code, MatchReduceFailureCode.matchAlreadyFinished);
    });

    test('finalizeMatch is idempotent on already finalized match state', () {
      final state = buildFinalizableMatch();
      const config = MatchFinalizationConfig(
        finishCondition: MatchFinishCondition.allPlayersFinished,
      );

      final first = finalizeMatch(state, config);
      expect(first.isSuccess, isTrue);
      final second = finalizeMatch(first.finishedMatchState!, config);
      expect(second.isSuccess, isTrue);
      expect(second.alreadyFinalized, isTrue);
      expect(second.result!.toMap(), equals(first.result!.toMap()));
    });

    test('FinalMatchResult serialization round-trip preserves equality', () {
      final state = buildFinalizableMatch();
      final finalized = finalizeMatch(
        state,
        const MatchFinalizationConfig(
          finishCondition: MatchFinishCondition.allPlayersFinished,
        ),
      );
      final result = finalized.result!;

      final decoded = FinalMatchResult.tryFromMap(result.toMap());
      expect(decoded.isSuccess, isTrue);
      expect(decoded.value!.toMap(), equals(result.toMap()));
      expect(decoded.value!.schemaVersion, result.schemaVersion);
      expect(decoded.value!.engineVersion, result.engineVersion);
    });
  });
}
