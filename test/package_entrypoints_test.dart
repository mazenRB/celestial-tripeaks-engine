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

    test('multiplayer entrypoint supports match setup', () {
      final match = MatchState.newMatch(
        config: const MatchConfig(
          matchMode: MatchMode.realtime,
          matchId: 'match-1',
          matchSeed: 7,
          maxPlayers: 2,
        ),
      );
      final joined = tryReduceMatch(
        match,
        const JoinMatchEvent(playerId: 'p1'),
      );

      expect(joined.isSuccess, isTrue);
      expect(joined.state.players.single.playerId, 'p1');
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
