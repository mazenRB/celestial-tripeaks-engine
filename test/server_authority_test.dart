import 'package:celestial_tripeaks/tripeaks_engine.dart';
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
      final match = MatchState.newMatch(config: config);
      return ServerAuthorityState.newAuthority(matchState: match);
    }

    test('duplicate same eventId is ignored without double apply', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;

      final before = authority.matchState;
      final duplicate = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );

      expect(duplicate.isSuccess, isTrue);
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.accepted, isFalse);
      expect(duplicate.state.matchState.toMap(), equals(before.toMap()));
      expect(duplicate.state.eventLog.last.outcome,
          ServerApplyStatus.duplicateIgnored);
    });

    test('out-of-order clientSeq is rejected deterministically', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 2,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;

      final outOfOrder = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 1,
          event: StartMatchEvent(),
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

        final join1 = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
        );
        expect(join1.accepted, isTrue);
        expect(join1.authoritativeSequence, 1);
        authority = join1.state;

        final join2 = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p2'),
          ),
        );
        expect(join2.accepted, isTrue);
        expect(join2.authoritativeSequence, 2);
        authority = join2.state;

        final start = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-2',
            clientSeq: 2,
            event: StartMatchEvent(),
          ),
        );
        expect(start.accepted, isTrue);
        expect(start.authoritativeSequence, 3);
        authority = start.state;

        final submit = applyClientEvent(
          authority,
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: SubmitMatchActionEvent(
              playerId: 'p1',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
        );
        expect(submit.accepted, isTrue);
        expect(submit.authoritativeSequence, 4);

        final player = submit.state.matchState.players
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
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p2'),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-2',
            clientSeq: 2,
            event: StartMatchEvent(),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: SubmitMatchActionEvent(
              playerId: 'p1',
              action: PlayRoundAction(DrawFromStockAction()),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-2',
            clientSeq: 2,
            event: SubmitMatchActionEvent(
              playerId: 'p2',
              action: PlayRoundAction(RemoveTableauCardAction(99)),
            ),
          ),
          const ClientEvent(
            matchId: 'srv',
            playerId: 'p2',
            clientEventId: 'p2-3',
            clientSeq: 3,
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
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 2,
          event: StartMatchEvent(),
        ),
      ).state;

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
        ),
      );

      expect(resultA.isSuccess, isTrue);
      expect(resultA.snapshot?.toMap(), equals(resultB.snapshot?.toMap()));
      expect(resultA.authoritativeSequence, beforeSeq);
      expect(authority.matchState.toMap(), equals(beforeMap));
      expect(authority.matchState.authoritativeSequence, beforeSeq);
    });

    test('reconnect detects fingerprint mismatch and flags full resync', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 2,
          event: StartMatchEvent(),
        ),
      ).state;

      final reconnect = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 2,
          lastKnownFingerprint: 'wrong-fingerprint',
        ),
      );

      expect(reconnect.isSuccess, isTrue);
      expect(reconnect.mustFullyResync, isTrue);
    });

    test('reconnect does not change authoritativeSequence', () {
      var authority = buildAuthority();
      authority = applyClientEvent(
        authority,
        const ClientEvent(
          matchId: 'srv',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      ).state;
      final beforeSeq = authority.matchState.authoritativeSequence;

      final reconnect = handleReconnect(
        authority,
        const ReconnectRequest(
          matchId: 'srv',
          playerId: 'p1',
          lastKnownAuthoritativeSequence: 1,
        ),
      );

      expect(reconnect.isSuccess, isTrue);
      expect(reconnect.authoritativeSequence, beforeSeq);
      expect(authority.matchState.authoritativeSequence, beforeSeq);
    });
  });
}
