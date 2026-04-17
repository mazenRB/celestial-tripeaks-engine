import 'dart:io';

import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_helpers.dart';
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

    test('helper entrypoint supports completed-run comparison', () {
      final baseline = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 42,
      );
      final better = tryReduceTriPeaksSession(
        baseline,
        const PlayRoundAction(DrawFromStockAction()),
      ).state;
      final result = compareCompletedRuns(
        <String, CompletedSessionResult>{
          'a': CompletedSessionResult.fromSession(baseline),
          'b': CompletedSessionResult.fromSession(better),
        },
      );

      expect(result.rankings, hasLength(2));
      expect(result.rankings.first.entryId, 'b');
    });

    test('package docs avoid src imports in consumer examples', () {
      final docs = <String>[
        'README.md',
        'docs/DETERMINISM.md',
        'docs/FLUTTER_INTEGRATION.md',
        'docs/engine_api_guide.md',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(docs.contains('package:celestial_tripeaks/src/'), isFalse);
    });
  });
}
