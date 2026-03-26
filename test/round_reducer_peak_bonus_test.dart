import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - peak bonus', () {
    test('clearing one peak awards peak bonus exactly once', () {
      var state = TriPeaksState.newGame(
        deck: buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 50);

      state = reduceTriPeaks(state, const RemoveTableauCardAction(22));
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 50);
    });

    test('clearing remaining peaks awards additional peak bonuses', () {
      var state = TriPeaksState.newGame(
        deck: buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
      );

      for (final index in <int>[
        18,
        19,
        20,
        21,
        9,
        10,
        11,
        3,
        4,
        0,
        22,
        23,
        24,
        12,
        13,
        14,
        6,
        5,
        1,
        25,
        26,
        27,
        17,
        16,
        15,
        8,
        7,
        2,
      ]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }

      expect(state.clearedPeaksAwarded, equals(<int>{0, 1, 2}));
      expect(state.scoreState.totalScore, 150);
    });

    test('undo restores peak bonus score and awarded tracking', () {
      var state = TriPeaksState.newGame(
        deck: buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 50,
        ),
        undoConfig: const UndoConfig(enabled: true, maxSteps: 20),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.scoreState.totalScore, 50);
      expect(state.clearedPeaksAwarded, equals(<int>{0}));

      state = reduceTriPeaks(state, const UndoAction());

      expect(state.scoreState.totalScore, 0);
      expect(state.clearedPeaksAwarded, isEmpty);
      expect(state.removed[0], isFalse);
    });

    test('no peak bonus is awarded when pointsPeakCleared is zero', () {
      var state = TriPeaksState.newGame(
        deck: buildPeakBonusDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 0,
          pointsPeakCleared: 0,
        ),
      );

      for (final index in <int>[18, 19, 20, 21, 9, 10, 11, 3, 4, 0]) {
        state = reduceTriPeaks(state, RemoveTableauCardAction(index));
      }
      expect(state.clearedPeaksAwarded, equals(<int>{0}));
      expect(state.scoreState.totalScore, 0);
    });
  });
}
