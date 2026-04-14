import 'package:celestial_tripeaks/tripeaks_authority.dart';
import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
  group('Server authority', () {
    ServerAuthorityState buildAuthority() {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'srv',
        matchSeed: 111,
        maxPlayers: 2,
      );
      final match = MatchState.newMatch(
        config: config,
        playerIds: const <String>['p1', 'p2'],
      );
      return ServerAuthorityState.newAuthority(matchState: match);
    }

    const drawP1 = ClientEvent(
      matchId: 'srv',
      playerId: 'p1',
      clientEventId: 'p1-1',
      clientSeq: 1,
      event: SubmitMatchActionEvent(
        playerId: 'p1',
        action: PlayRoundAction(DrawFromStockAction()),
      ),
    );

    test('duplicate same eventId is ignored without double apply', () {
      var authority = buildAuthority();
      authority = applyClientEvent(authority, drawP1).state;

      final before = authority.matchState;
      final duplicate = applyClientEvent(authority, drawP1);

      expect(duplicate.isSuccess, isTrue);
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.accepted, isFalse);
      expect(duplicate.state.matchState.toMap(), equals(before.toMap()));
      expect(
        duplicate.state.eventLog.last.outcome,
        ServerApplyStatus.duplicateIgnored,
      );
    });

    test('out-of-order clientSeq is rejected deterministically', () {
      var authority = buildAuthority();
      authority = applyClientEvent(authority, drawP1).state;

      final outOfOrder = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 1,
          event: SubmitMatchActionEvent(
            playerId: 'p1',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ),
      );

      expect(outOfOrder.accepted, isFalse);
      expect(outOfOrder.status, ServerApplyStatus.rejected);
      expect(outOfOrder.reason, ServerRejectReason.outOfOrderOrDuplicate);
      expect(
        outOfOrder.state.eventLog.last.rejectReason,
        ServerRejectReason.outOfOrderOrDuplicate,
      );
    });

    test(
      'accepted events increment authoritativeSequence and update state correctly',
      () {
        var authority = buildAuthority();

        final first = applyClientEvent(authority, drawP1);
        expect(first.accepted, isTrue);
        expect(first.authoritativeSequence, 1);
        authority = first.state;

        final second = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
        );
        expect(second.accepted, isTrue);
        expect(second.authoritativeSequence, 2);

        final player = second.state.matchState.players
            .firstWhere((value) => value.playerId == 'p1');
        expect(player.replay, isNotNull);
        expect(player.replay!.entries, isNotEmpty);
        expect(player.latestFingerprint, isNotNull);
      },
    );

    test(
      'deterministic replay from accepted server log reproduces authoritative match state',
      () {
        var authority = buildAuthority();
        final initial = authority.matchState;

        for (final event in <ClientEvent>[
          drawP1,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-2',
            clientSeq: 2,
            event: SubmitMatchActionEvent(
              playerId: 'p1',
              action: PlayRoundAction(RemoveTableauCardAction(99)),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-2',
            clientSeq: 2,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(UndoAction()),
            ),
          ),
        ]) {
          authority = applyClientEvent(authority, event).state;
        }

        final replayed =
            replayAcceptedServerEvents(initial, authority.eventLog);
        expect(replayed.toMap(), equals(authority.matchState.toMap()));
      },
    );

    test('reconnect returns consistent state and does not mutate authority',
        () {
      var authority = buildAuthority();
      authority = applyClientEvent(authority, drawP1).state;

      final beforeMap = authority.matchState.toMap();
      final beforeSeq = authority.matchState.authoritativeSequence;
      final resultA = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 0,
        ),
      );
      final resultB = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 0,
          lastKnownFingerprint: 'mismatch',
        ),
      );

      expect(resultA.isSuccess, isTrue);
      expect(resultA.snapshot!.toMap(), equals(beforeMap));
      expect(resultB.mustFullyResync, isTrue);
      expect(authority.matchState.toMap(), equals(beforeMap));
      expect(authority.matchState.authoritativeSequence, beforeSeq);
    });
  });
}
