import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TriPeaks session reducer - core', () {
    test('supports 1, 3, 6, and 10 rounds via ruleset', () {
      final one = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.oneRound,
        seed: 1,
      );
      final three = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 1,
      );
      final six = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.sixRounds,
        seed: 1,
      );
      final ten = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.tenRounds,
        seed: 1,
      );

      expect(one.ruleset.roundsPerGame, 1);
      expect(three.ruleset.roundsPerGame, 3);
      expect(six.ruleset.roundsPerGame, 6);
      expect(ten.ruleset.roundsPerGame, 10);
    });

    test('uses deterministic default seed for sessions', () {
      final sessionA = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );
      final sessionB = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
      );

      expect(
        sessionA.currentRound.tableau,
        equals(sessionB.currentRound.tableau),
      );
      expect(sessionA.currentRound.waste, equals(sessionB.currentRound.waste));
      expect(sessionA.currentRound.stock, equals(sessionB.currentRound.stock));
    });

    test('cannot start next round before current round finishes', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 2,
      );

      final result = tryReduceTriPeaksSession(
        session,
        const StartNextRoundAction(),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.sessionError?.code,
        TriPeaksSessionErrorCode.roundNotFinished,
      );
    });

    test('session decode derives missing roundSeed from session seed + index',
        () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 40,
      );
      final map = session.toMap();
      final currentRound = map['currentRound'] as Map<String, dynamic>;
      currentRound.remove('roundSeed');

      final decoded = TriPeaksSessionState.tryFromMap(map);
      expect(decoded.isSuccess, isTrue);
      final restored = decoded.value!;
      expect(restored.currentRound.roundSeed, 40);
    });

    test('session uses configured invalid-action penalty', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 13,
        scoreConfig: const ScoreConfig(penaltyInvalidAction: -3),
      );

      final result = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(RemoveTableauCardAction(99)),
      );

      expect(result.isSuccess, isFalse);
      expect(result.roundError?.code, TriPeaksErrorCode.invalidTableauIndex);
      expect(result.state.currentRound.scoreState.totalScore, -3);
      expect(result.state.currentRound.scoreState.lastDelta, -3);
      expect(result.state.currentRound.scoreState.movesCount, 1);
    });

    test('session respects non-negative score clamp when disabled', () {
      final session = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 13,
        scoreConfig: const ScoreConfig(
          penaltyInvalidAction: -3,
          allowNegativeTotalScore: false,
        ),
      );

      final result = tryReduceTriPeaksSession(
        session,
        const PlayRoundAction(RemoveTableauCardAction(99)),
      );

      expect(result.isSuccess, isFalse);
      expect(result.roundError?.code, TriPeaksErrorCode.invalidTableauIndex);
      expect(result.state.currentRound.scoreState.totalScore, 0);
      expect(result.state.currentRound.scoreState.lastDelta, 0);
      expect(result.state.currentRound.scoreState.movesCount, 1);
    });
  });
}
