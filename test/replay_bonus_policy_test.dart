import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Replay - bonus slot policies', () {
    test(
      'tierFixedRank anchor behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 0,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
            lowTierAnchorRank: Rank.six,
            highTierAnchorRank: Rank.queen,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: 0,
          ruleset: TriPeaksRuleset.threeRounds,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
            lowTierAnchorRank: Rank.six,
            highTierAnchorRank: Rank.queen,
          ),
        );

        var guard = 0;
        while (liveState.currentRound.streakState.currentStreak < 3 &&
            guard < 64) {
          final moves =
              liveState.currentRound.availableMoves.removableTableauIndices;
          final action = moves.isNotEmpty
              ? PlayRoundAction(RemoveTableauCardAction(moves.first))
              : const PlayRoundAction(DrawFromStockAction());
          final recorded = recordAction(replay, liveState, action);
          replay = recorded.replay;
          liveState = recorded.state;
          guard++;
        }
        expect(liveState.currentRound.streakState.currentStreak,
            greaterThanOrEqualTo(3));

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.isAnchor,
          isTrue,
        );
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.rank,
          liveState.currentRound.bonusSlotsState.slots[1].single.rank,
        );
        expect(sessionFingerprint(rebuilt), sessionFingerprint(liveState));
      },
    );

    test(
      'tierRandomRank anchor behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 11,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.tierRandomRank,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: liveState.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: liveState.ruleset,
          scoreConfig: liveState.scoreConfig,
          roundRulesConfig: liveState.roundRulesConfig,
          undoConfig: liveState.undoConfig,
          streakConfig: liveState.streakConfig,
          strikeTimerConfig: liveState.strikeTimerConfig,
          bonusSlotsConfig: liveState.bonusSlotsConfig,
        );

        var guard = 0;
        while (liveState.currentRound.streakState.currentStreak < 3 &&
            guard < 64) {
          final moves =
              liveState.currentRound.availableMoves.removableTableauIndices;
          final action = moves.isNotEmpty
              ? PlayRoundAction(RemoveTableauCardAction(moves.first))
              : const PlayRoundAction(DrawFromStockAction());
          final recorded = recordAction(replay, liveState, action);
          replay = recorded.replay;
          liveState = recorded.state;
          guard++;
        }
        expect(
          liveState.currentRound.streakState.currentStreak,
          greaterThanOrEqualTo(3),
        );

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.isAnchor,
          isTrue,
        );
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single.rank,
          liveState.currentRound.bonusSlotsState.slots[1].single.rank,
        );
        expect(
          rebuilt.currentRound.bonusAnchorSpawnNonce,
          liveState.currentRound.bonusAnchorSpawnNonce,
        );
        expect(sessionFingerprint(rebuilt), sessionFingerprint(liveState));
      },
    );

    test(
      'stockTopCard bonus behavior is preserved in replay reconstruction',
      () {
        var liveState = TriPeaksSessionState.newSession(
          ruleset: TriPeaksRuleset.threeRounds,
          seed: 11,
          streakConfig: const StreakConfig(resetOnDraw: false),
          bonusSlotsConfig: const BonusSlotsConfig(
            spawnPolicy: BonusSlotSpawnPolicy.stockTopCard,
          ),
        );
        var replay = TriPeaksReplay.newSession(
          seed: liveState.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: liveState.ruleset,
          scoreConfig: liveState.scoreConfig,
          roundRulesConfig: liveState.roundRulesConfig,
          undoConfig: liveState.undoConfig,
          streakConfig: liveState.streakConfig,
          strikeTimerConfig: liveState.strikeTimerConfig,
          bonusSlotsConfig: liveState.bonusSlotsConfig,
        );

        var guard = 0;
        while (liveState.currentRound.bonusSlotsState.openSlotsCount < 2 &&
            guard < 64) {
          final moves =
              liveState.currentRound.availableMoves.removableTableauIndices;
          final action = moves.isNotEmpty
              ? PlayRoundAction(RemoveTableauCardAction(moves.first))
              : const PlayRoundAction(DrawFromStockAction());
          final recorded = recordAction(replay, liveState, action);
          replay = recorded.replay;
          liveState = recorded.state;
          guard++;
        }
        expect(liveState.currentRound.bonusSlotsState.openSlotsCount, 2);

        final rebuilt = replayToState(replay);
        expect(
          rebuilt.currentRound.bonusSlotsState.slots[1].single,
          liveState.currentRound.bonusSlotsState.slots[1].single,
        );
        expect(rebuilt.currentRound.stock, liveState.currentRound.stock);
        expect(sessionFingerprint(rebuilt), sessionFingerprint(liveState));
      },
    );
  });
}
