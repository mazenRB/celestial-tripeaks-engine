import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Fingerprint', () {
    test('identical states produce identical fingerprint', () {
      final stateA = TriPeaksState.newGame(seed: 12);
      final stateB = TriPeaksState.newGame(seed: 12);

      expect(stateFingerprint(stateA), stateFingerprint(stateB));
    });

    test('small state change produces a different fingerprint', () {
      final state = TriPeaksState.newGame(seed: 12);
      final changed = reduceTriPeaks(state, const DrawFromStockAction());

      expect(stateFingerprint(state), isNot(stateFingerprint(changed)));
    });

    test('fingerprint is stable for fixed canonical state', () {
      final state = TriPeaksState.newGame(seed: 42);
      expect(stateFingerprint(state), '8614e617');
    });
  });
}
