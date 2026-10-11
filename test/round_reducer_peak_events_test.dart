import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';
import 'test_support.dart';

void main() {
  group('TriPeaks reducer peak events', () {
    test('returns no events when a valid move clears no peak', () {
      final state = _newGame();

      final result = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );

      expect(result.isSuccess, isTrue);
      expect(result.peakClearedEvents, isEmpty);
    });

    test('reports a peak once with unmultiplied configured points', () {
      var state = _newGame(
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
          streakStepSize: 1,
          multiplierStepIncrement: 1,
          multiplierMax: 10,
        ),
      );
      late TriPeaksReduceResult result;
      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        result = tryReduceTriPeaks(
          state,
          RemoveTableauCardAction(index),
        );
        expect(result.isSuccess, isTrue, reason: 'card $index should be legal');
        state = result.state;
      }

      expect(
        result.peakClearedEvents.map((event) => event.toMap()).toList(),
        <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'peak_cleared_event',
            'schemaVersion': 1,
            'peakId': 0,
            'pointsAwarded': 50,
          },
        ],
      );
      expect(result.appliedMultiplier, greaterThan(1));
      expect(result.scoreBreakdown.peakBonusPoints, 50);
      expect(
        result.peakClearedEvents.fold<int>(
          0,
          (sum, event) => sum + event.pointsAwarded,
        ),
        result.scoreBreakdown.peakBonusPoints,
      );
      expect(
        () => result.peakClearedEvents.add(
          const PeakClearedEvent(peakId: 1, pointsAwarded: 50),
        ),
        throwsUnsupportedError,
      );

      final laterResult = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(22),
      );
      expect(laterResult.isSuccess, isTrue);
      expect(laterResult.peakClearedEvents, isEmpty);
    });

    test('returns no peak events for an invalid action', () {
      final result = tryReduceTriPeaks(
        _newGame(),
        const RemoveTableauCardAction(99),
      );

      expect(result.isSuccess, isFalse);
      expect(result.peakClearedEvents, isEmpty);
    });

    test('reports each peak completed by one action', () {
      final state = _stateWithTwoPeaksToClear();

      final result = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(21),
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.peakClearedEvents
            .map((event) => <int>[event.peakId, event.pointsAwarded])
            .toList(),
        <List<int>>[
          <int>[0, 25],
          <int>[1, 25],
        ],
      );
      expect(
        result.peakClearedEvents.fold<int>(
          0,
          (sum, event) => sum + event.pointsAwarded,
        ),
        result.scoreBreakdown.peakBonusPoints,
      );
    });

    test('reports a newly cleared peak when its configured points are zero',
        () {
      var state = _newGame(
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 0,
        ),
      );
      late TriPeaksReduceResult result;
      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        result = tryReduceTriPeaks(
          state,
          RemoveTableauCardAction(index),
        );
        expect(result.isSuccess, isTrue, reason: 'card $index should be legal');
        state = result.state;
      }

      expect(result.peakClearedEvents.length, 1);
      expect(result.peakClearedEvents.single.peakId, 0);
      expect(result.peakClearedEvents.single.pointsAwarded, 0);
      expect(result.scoreBreakdown.peakBonusPoints, 0);
    });
  });
}

TriPeaksState _newGame({
  ScoreConfig scoreConfig = const ScoreConfig(pointsTableauToWaste: 0),
}) {
  return TriPeaksState.newGame(
    deck: buildPeakBonusDeck(),
    scoreConfig: scoreConfig,
  );
}

TriPeaksState _stateWithTwoPeaksToClear() {
  final initialState = _newGame(
    scoreConfig: const ScoreConfig(
      pointsTableauToWaste: 0,
      pointsPeakCleared: 25,
    ),
  );
  final payload = initialState.toMap();
  final removed = List<bool>.filled(initialState.removed.length, true);
  removed[21] = false;
  payload['removed'] = removed;
  payload['clearedPeaksAwardedMask'] = 4;

  final decoded = TriPeaksState.tryFromMap(payload);
  expect(decoded.isSuccess, isTrue);
  var state = decoded.value!;
  while (!state.canRemoveTableau(21) && state.stock.isNotEmpty) {
    final draw = tryReduceTriPeaks(state, const DrawFromStockAction());
    expect(draw.isSuccess, isTrue);
    state = draw.state;
  }
  expect(state.canRemoveTableau(21), isTrue);
  return state;
}
