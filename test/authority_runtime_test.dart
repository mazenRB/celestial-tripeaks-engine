import 'dart:io';

import 'package:celestial_tripeaks/tripeaks_authority.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
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
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources.contains('DateTime.now('), isFalse);
  });
}
