import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';
import 'package:test/test.dart';

void main() {
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
}
