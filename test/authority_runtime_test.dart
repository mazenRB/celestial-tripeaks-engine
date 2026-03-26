import 'dart:io';

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
      expect(outOfOrder.state.eventLog.last.rejectReason,
          ServerRejectReason.outOfOrderOrDuplicate);
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

        final replayed = replayAcceptedServerEvents(
          initial,
          authority.eventLog,
        );
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

  group('Authority runtime', () {
    MatchState buildInitialMatch({String matchId = 'runtime'}) {
      return MatchState.newMatch(
        config: MatchConfig(
          matchMode: MatchMode.realtime,
          matchId: matchId,
          matchSeed: 123,
          maxPlayers: 2,
        ),
      );
    }

    test('baseline starts at sequence 0 and first accepted event is 1',
        () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final restored = await runtime.restore('runtime');
      expect(restored.isSuccess, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 0);

      final apply = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'client-side-value-is-ignored',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );

      expect(apply.accepted, isTrue);
      expect(apply.authoritativeSequence, 1);

      final tail = await store.loadAcceptedEventsAfter('runtime', 0);
      expect(tail, hasLength(1));
      expect(tail.first.authoritativeSequence, 1);
    });

    test('append failure never returns accepted and state is not committed',
        () async {
      final store = InMemoryAuthorityStore(
        shouldFailAppend: (_, __) => true,
      );
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final result = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.rejected, isTrue);
      expect(
        result.failure?.code,
        AuthorityApplyFailureCode.durabilityFailure,
      );
      expect(runtime.state.matchState.authoritativeSequence, 0);
      expect(store.acceptedEvents('runtime'), isEmpty);
    });

    test('duplicate and rejected outcomes are not written to accepted log',
        () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );

      final accepted = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(accepted.accepted, isTrue);

      final duplicate = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.authoritativeSequence, 1);
      expect(duplicate.lastAcceptedClientSeq, 1);

      final rejected = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-2',
          clientSeq: 1,
          event: StartMatchEvent(),
        ),
      );
      expect(rejected.rejected, isTrue);
      expect(rejected.mustFullyResync, isTrue);

      expect(store.acceptedEvents('runtime'), hasLength(1));
    });

    test('restore rebuilds clientSeq and idempotency windows', () async {
      final store = InMemoryAuthorityStore();
      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
        config: const AuthorityRuntimeConfig(
          snapshotEveryAccepted: 1,
          processedClientEventIdsCapacityPerPlayer: 1000,
        ),
      );

      final accepted = await runtime.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
      );
      expect(accepted.accepted, isTrue);

      final restarted = AuthorityRuntime(
        store: store,
        initialMatchState: buildInitialMatch(),
      );
      final restored = await restarted.restore('runtime');
      expect(restored.isSuccess, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 1);

      final duplicate = await restarted.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'ignored',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );
      expect(duplicate.duplicateIgnored, isTrue);
      expect(duplicate.lastAcceptedClientSeq, 1);

      final stale = await restarted.apply(
        const AuthorityRequestContext(subjectId: 's1', playerId: 'p1'),
        const ClientEvent(
          matchId: 'runtime',
          playerId: 'ignored',
          clientEventId: 'p1-stale',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'ignored'),
        ),
      );
      expect(stale.rejected, isTrue);
      expect(stale.mustFullyResync, isTrue);
    });

    test('restore falls back on invalid snapshot and replays from sequence 0',
        () async {
      final store = InMemoryAuthorityStore();
      final initial = buildInitialMatch();
      final acceptedRecord = ServerEventRecord(
        clientEvent: const ClientEvent(
          matchId: 'runtime',
          playerId: 'p1',
          clientEventId: 'p1-1',
          clientSeq: 1,
          event: JoinMatchEvent(playerId: 'p1'),
        ),
        outcome: ServerApplyStatus.accepted,
        authoritativeSequence: 1,
      );
      store.seedAcceptedEvents(
        'runtime',
        <PersistedAuthorityEvent>[
          PersistedAuthorityEvent.fromAcceptedRecord(
            engineVersion: initial.engineVersion,
            matchId: 'runtime',
            record: acceptedRecord,
          ),
        ],
      );
      store.seedSnapshot(
        'runtime',
        PersistedAuthoritySnapshot(
          schemaVersion: 1,
          engineVersion: initial.engineVersion,
          matchId: 'wrong',
          authoritativeSequence: 1,
          matchState: tryReduceMatch(
            initial,
            const JoinMatchEvent(playerId: 'p1'),
          ).state,
          matchFingerprint: 'invalid',
          recentClientEventIdsByPlayer: const <String, List<String>>{},
          lastAcceptedClientSeqByPlayer: const <String, int>{},
        ),
      );

      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: initial,
      );
      final restored = await runtime.restore('runtime');

      expect(restored.isSuccess, isTrue);
      expect(restored.usedSnapshotFallback, isTrue);
      expect(restored.state.matchState.authoritativeSequence, 1);
    });

    test('restore fails on sequence gap in accepted tail', () async {
      final store = InMemoryAuthorityStore();
      final initial = buildInitialMatch();
      final accepted1 = PersistedAuthorityEvent.fromAcceptedRecord(
        engineVersion: initial.engineVersion,
        matchId: 'runtime',
        record: const ServerEventRecord(
          clientEvent: ClientEvent(
            matchId: 'runtime',
            playerId: 'p1',
            clientEventId: 'p1-1',
            clientSeq: 1,
            event: JoinMatchEvent(playerId: 'p1'),
          ),
          outcome: ServerApplyStatus.accepted,
          authoritativeSequence: 1,
        ),
      );
      final accepted3 = PersistedAuthorityEvent.fromAcceptedRecord(
        engineVersion: initial.engineVersion,
        matchId: 'runtime',
        record: const ServerEventRecord(
          clientEvent: ClientEvent(
            matchId: 'runtime',
            playerId: 'p1',
            clientEventId: 'p1-3',
            clientSeq: 3,
            event: StartMatchEvent(),
          ),
          outcome: ServerApplyStatus.accepted,
          authoritativeSequence: 3,
        ),
      );
      store.seedAcceptedEvents('runtime', <PersistedAuthorityEvent>[
        accepted1,
        accepted3,
      ]);

      final runtime = AuthorityRuntime(
        store: store,
        initialMatchState: initial,
      );
      final restored = await runtime.restore('runtime');

      expect(restored.isSuccess, isFalse);
      expect(restored.failure?.code, AuthorityRestoreFailureCode.sequenceGap);
    });
  });

  test('engine source does not call DateTime.now', () {
    final source = File('lib/tripeaks_engine.dart').readAsStringSync();
    expect(source.contains('DateTime.now('), isFalse);
  });
}
