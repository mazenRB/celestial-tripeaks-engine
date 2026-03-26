import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('TriPeaks reducer - score breakdown', () {
    test('breakdown invariants hold and match score state/result', () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 7,
          pointsDrawFromStock: 2,
          penaltyInvalidAction: -3,
          streakStepSize: 2,
          multiplierStepIncrement: 1,
          multiplierMax: 4,
        ),
      );
      final results = <TriPeaksReduceResult>[
        tryReduceTriPeaks(state, const RemoveTableauCardAction(18)),
      ];
      state = results.last.state;
      results.add(tryReduceTriPeaks(state, const DrawFromStockAction()));
      state = results.last.state;
      results.add(tryReduceTriPeaks(state, const RemoveTableauCardAction(99)));

      for (final result in results) {
        final breakdown = result.scoreBreakdown;
        expect(breakdown.appliedMultiplier, greaterThanOrEqualTo(1));
        expect(
          breakdown.multiplierExtraPoints,
          breakdown.tableauBasePoints * (breakdown.appliedMultiplier - 1),
        );
        expect(
          breakdown.totalDelta,
          breakdown.tableauBasePoints +
              breakdown.multiplierExtraPoints +
              breakdown.peakBonusPoints +
              breakdown.drawPoints +
              breakdown.invalidPenaltyPoints +
              breakdown.endRoundRemainingStockBonusPoints,
        );
        expect(result.scoreDelta, breakdown.totalDelta);
        expect(result.state.scoreState.lastDelta, breakdown.totalDelta);
        expect(result.scoreBreakdown,
            equals(result.state.scoreState.lastBreakdown));
        expect(result.appliedMultiplier,
            result.state.scoreState.currentMultiplier);
      }
    });

    test('undo restores prior score state and result breakdown mirrors restore',
        () {
      var state = TriPeaksState.newGame(
        deck: buildStreakUnlockDeck(),
        scoreConfig: const ScoreConfig(pointsDrawFromStock: 2),
        undoConfig: const UndoConfig(enabled: true, maxSteps: 5),
      );
      final first = tryReduceTriPeaks(state, const DrawFromStockAction());
      state = first.state;
      final restoredSnapshot = state.scoreState;

      final second = tryReduceTriPeaks(state, const DrawFromStockAction());
      state = second.state;
      expect(state.scoreState.totalScore, 4);

      final undo = tryReduceTriPeaks(state, const UndoAction());
      expect(undo.isSuccess, isTrue);
      expect(undo.scoreDelta, 0);
      expect(undo.state.scoreState.totalScore, restoredSnapshot.totalScore);
      expect(undo.state.scoreState.lastDelta, restoredSnapshot.lastDelta);
      expect(
        undo.state.scoreState.currentMultiplier,
        restoredSnapshot.currentMultiplier,
      );
      expect(
          undo.state.scoreState.lastBreakdown, restoredSnapshot.lastBreakdown);
      expect(undo.scoreBreakdown, equals(restoredSnapshot.lastBreakdown));
      expect(undo.appliedMultiplier, restoredSnapshot.currentMultiplier);
    });

    test('win awards remaining stock bonus exactly once', () {
      final config = const ScoreConfig(pointsPerRemainingStockCardOnWin: 2);
      final deck = buildDeckWithBottomRow(
        waste: const Card(Rank.six, Suit.spades),
        bottomRow: <Card>[
          const Card(Rank.five, Suit.clubs),
          const Card(Rank.two, Suit.clubs),
          const Card(Rank.three, Suit.clubs),
          const Card(Rank.four, Suit.clubs),
          const Card(Rank.five, Suit.hearts),
          const Card(Rank.six, Suit.hearts),
          const Card(Rank.seven, Suit.hearts),
          const Card(Rank.eight, Suit.hearts),
          const Card(Rank.nine, Suit.hearts),
          const Card(Rank.ten, Suit.hearts),
        ],
      );
      final base = TriPeaksState.newGame(deck: deck, scoreConfig: config);
      final map = base.toMap();
      map['removed'] = List<bool>.generate(
        28,
        (index) => index != 18,
        growable: false,
      );
      final restored = TriPeaksState.tryFromMap(map);
      expect(restored.isSuccess, isTrue);
      final state = restored.value!;

      final result = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(18),
      );

      expect(result.isSuccess, isTrue);
      expect(result.state.isWon, isTrue);
      final bonus =
          result.state.stockCount * config.pointsPerRemainingStockCardOnWin;
      expect(
        result.scoreBreakdown.endRoundRemainingStockBonusPoints,
        bonus,
      );
      expect(result.scoreBreakdown.totalDelta, result.scoreDelta);

      final after = tryReduceTriPeaks(result.state, const UndoAction());
      expect(after.isSuccess, isTrue);
      expect(after.state.isWon, isFalse);
      final reapply = tryReduceTriPeaks(
        after.state,
        const RemoveTableauCardAction(18),
      );
      expect(reapply.isSuccess, isTrue);
      expect(
        reapply.scoreBreakdown.endRoundRemainingStockBonusPoints,
        bonus,
      );
    });
  });
}
