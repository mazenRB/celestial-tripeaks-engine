import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
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
