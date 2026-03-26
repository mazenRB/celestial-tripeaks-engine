import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Deal policy', () {
    test('random mode returns deal on first attempt', () {
      final result = newGameWithDealPolicy(
        123,
        dealPolicy: const DealPolicyConfig(mode: DealPolicyMode.random),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state, isNotNull);
      expect(result.attemptCount, 1);
      expect(result.attemptSeed, 123);
    });

    test(
      'requireSolvable returns solvable deal or typed failure within maxAttempts',
      () {
        const policy = DealPolicyConfig(
          mode: DealPolicyMode.requireSolvable,
          maxAttempts: 5,
          solverNodeLimit: 50000,
        );
        final result = newGameWithDealPolicy(123, dealPolicy: policy);

        if (result.isSuccess) {
          expect(result.state, isNotNull);
          expect(isDealSolvable(result.state!), isTrue);
          expect(result.attemptCount!, inInclusiveRange(1, policy.maxAttempts));
        } else {
          expect(result.failure?.code, DealFailureCode.noSolvableDealFound);
        }
      },
    );

    test('same inputs produce same selected deal for requireSolvable', () {
      const policy = DealPolicyConfig(
        mode: DealPolicyMode.requireSolvable,
        maxAttempts: 20,
        attemptSeedStrategy: AttemptSeedStrategy.fnv1aMix,
        solverNodeLimit: 70000,
      );
      final a = newGameWithDealPolicy(777, dealPolicy: policy);
      final b = newGameWithDealPolicy(777, dealPolicy: policy);

      expect(a.isSuccess, b.isSuccess);
      if (!a.isSuccess) {
        expect(a.failure?.code, b.failure?.code);
        return;
      }
      expect(a.attemptSeed, b.attemptSeed);
      expect(a.attemptCount, b.attemptCount);
      expect(a.state!.tableau, equals(b.state!.tableau));
      expect(a.state!.waste, equals(b.state!.waste));
      expect(a.state!.stock, equals(b.state!.stock));
    });
  });
}
