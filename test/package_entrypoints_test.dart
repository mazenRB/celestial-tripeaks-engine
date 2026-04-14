import 'dart:io';

import 'package:celestial_tripeaks/tripeaks_authority.dart';
import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';
import 'package:test/test.dart';

void main() {
  group('Package entrypoints', () {
    test('core entrypoint supports a basic session flow', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 42,
      );
      final reduced = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(DrawFromStockAction()),
      );

      expect(reduced.isSuccess, isTrue);
      expect(reduced.state.currentRound.scoreState.movesCount, 1);
    });

    test('replay entrypoint supports replay and save helpers', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 42,
      );
      final replay = TriPeaksReplay.newSession(
        seed: 42,
        ruleset: TriPeaksRuleset.threeRounds,
      );
      final recorded = recordAction(
        replay,
        session,
        const PlayRoundAction(DrawFromStockAction()),
        tick: 1,
      );
      final save = encodeSaveReplay(recorded.replay);
      final decoded = decodeSaveReplay(save);

      expect(recorded.replay.entries, hasLength(1));
      expect(decoded.isSuccess, isTrue);
      expect(replayFingerprint(recorded.replay), isNotEmpty);
    });

    test('multiplayer entrypoint supports room bootstrap', () {
      var room = RoomState.newRoom(
        config: const RoomConfig(
          roomId: 'room-1',
          matchMode: MatchMode.realtime,
          minMembers: 2,
          maxMembers: 2,
        ),
      );
      room = tryReduceRoom(
        room,
        const JoinRoomEvent(memberId: 'p1'),
      ).state;
      room = tryReduceRoom(
        room,
        const JoinRoomEvent(memberId: 'p2'),
      ).state;
      final started = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 7,
        ),
      );

      expect(started.isSuccess, isTrue);
      expect(started.bootstrap, isNotNull);
      expect(started.bootstrap!.matchState.players.length, 2);
    });

    test('authority entrypoint supports runtime construction', () {
      final runtime = AuthorityRuntime(
        store: InMemoryAuthorityStore(),
        initialMatchState: MatchState.newMatch(
          config: const MatchConfig(
            matchMode: MatchMode.realtime,
            matchId: 'runtime',
            matchSeed: 9,
            maxPlayers: 2,
          ),
          playerIds: const <String>['p1', 'p2'],
        ),
      );

      expect(runtime, isA<AuthorityRuntime>());
    });

    test('package docs avoid src imports in consumer examples', () {
      final docs = <String>[
        'README.md',
        'docs/DETERMINISM.md',
        'docs/FLUTTER_INTEGRATION.md',
        'docs/engine_api_guide.md',
        'docs/authority_runtime_integration.md',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(docs.contains('package:celestial_tripeaks/src/'), isFalse);
    });
  });
}
