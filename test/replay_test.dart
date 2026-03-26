import 'dart:convert';

import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Replay', () {
    test('replayToState matches live state for same action sequence', () {
      final config = ScoreConfig(
        pointsTableauToWaste: 7,
        pointsDrawFromStock: 2,
        penaltyInvalidAction: -3,
      );
      var liveState = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 42,
        scoreConfig: config,
        undoConfig: const UndoConfig(maxSteps: 4),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
      );
      var replay = TriPeaksReplay.newSession(
        seed: 42,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: config,
        undoConfig: const UndoConfig(maxSteps: 4),
        streakConfig: const StreakConfig(resetOnInvalidAction: true),
      );
      final actions = <({TriPeaksSessionAction action, int? tick})>[
        (action: const PlayRoundAction(DrawFromStockAction()), tick: 1),
        (action: const PlayRoundAction(RemoveTableauCardAction(99)), tick: 2),
        (action: const PlayRoundAction(UndoAction()), tick: 3),
        (action: const AbortRoundAction(reason: AbortReason.userSkip), tick: 4),
      ];

      for (final item in actions) {
        final recorded = recordAction(
          replay,
          liveState,
          item.action,
          tick: item.tick,
        );
        replay = recorded.replay;
        liveState = recorded.state;
      }

      final rebuilt = replayToState(replay);

      expect(rebuilt.currentRoundNumber, liveState.currentRoundNumber);
      expect(rebuilt.roundsCompleted, liveState.roundsCompleted);
      expect(rebuilt.roundsWon, liveState.roundsWon);
      expect(rebuilt.roundsLost, liveState.roundsLost);
      expect(rebuilt.roundsAborted, liveState.roundsAborted);
      expect(
        rebuilt.roundResults.map((result) {
          return (
            result.roundNumber,
            result.outcome,
            result.abortReason,
            result.finalScore,
          );
        }).toList(growable: false),
        equals(
          liveState.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
              result.finalScore,
            );
          }).toList(growable: false),
        ),
      );
      expect(
          rebuilt.currentRound.tableau, equals(liveState.currentRound.tableau));
      expect(
          rebuilt.currentRound.removed, equals(liveState.currentRound.removed));
      expect(rebuilt.currentRound.waste, equals(liveState.currentRound.waste));
      expect(rebuilt.currentRound.stock, equals(liveState.currentRound.stock));
      expect(
        rebuilt.currentRound.scoreState.totalScore,
        liveState.currentRound.scoreState.totalScore,
      );
      expect(
        rebuilt.currentRound.streakState.currentStreak,
        liveState.currentRound.streakState.currentStreak,
      );
    });

    test('rejected attempts do not change replayed state', () {
      final state = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 33,
        undoConfig: const UndoConfig(enabled: false),
      );
      var replay = ReplaySession.newSession(
        seed: 33,
        ruleset: TriPeaksRuleset.threeRounds,
        undoConfig: const UndoConfig(enabled: false),
      );

      final rejected = tryReduceTriPeaksSession(
        state,
        const PlayRoundAction(UndoAction()),
      );
      replay = recordAttempt(
        replay,
        const PlayRoundAction(UndoAction()),
        rejected,
      );

      expect(replay.entries.single.accepted, isFalse);
      expect(
        replay.entries.single.failureReason,
        ReplayFailureReason.undoDisabled,
      );

      final rebuilt = replayToState(replay);
      expect(rebuilt.currentRound.tableau, equals(state.currentRound.tableau));
      expect(rebuilt.currentRound.removed, equals(state.currentRound.removed));
      expect(rebuilt.currentRound.waste, equals(state.currentRound.waste));
      expect(rebuilt.currentRound.stock, equals(state.currentRound.stock));
    });

    test('replay map round-trip preserves deterministic reconstruction', () {
      var state = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 11,
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          pointsDrawFromStock: 1,
          penaltyInvalidAction: -3,
        ),
      );
      var replay = TriPeaksReplay.newSession(
        seed: 11,
        ruleset: TriPeaksRuleset.threeRounds,
        scoreConfig: const ScoreConfig(
          pointsTableauToWaste: 5,
          pointsDrawFromStock: 1,
          penaltyInvalidAction: -3,
        ),
      );

      for (final action in <TriPeaksSessionAction>[
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(DrawFromStockAction()),
        const PlayRoundAction(RemoveTableauCardAction(99)),
        const PlayRoundAction(UndoAction()),
      ]) {
        final recorded = recordAction(replay, state, action);
        replay = recorded.replay;
        state = recorded.state;
      }

      final encoded = jsonEncode(replay.toMap());
      final decodeResult = ReplaySession.tryFromMap(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decodeResult.isSuccess, isTrue);
      final decoded = decodeResult.value!;

      final rebuiltOriginal = replayToState(replay);
      final rebuiltDecoded = replayToState(decoded);

      expect(
        rebuiltOriginal.currentRound.tableau,
        equals(rebuiltDecoded.currentRound.tableau),
      );
      expect(
        rebuiltOriginal.currentRound.removed,
        equals(rebuiltDecoded.currentRound.removed),
      );
      expect(
        rebuiltOriginal.currentRound.waste,
        equals(rebuiltDecoded.currentRound.waste),
      );
      expect(
        rebuiltOriginal.currentRound.stock,
        equals(rebuiltDecoded.currentRound.stock),
      );
      expect(
        rebuiltOriginal.currentRound.scoreState.totalScore,
        rebuiltDecoded.currentRound.scoreState.totalScore,
      );
      expect(
        rebuiltOriginal.roundResults.map((result) {
          return (
            result.roundNumber,
            result.outcome,
            result.abortReason,
            result.finalScore,
          );
        }).toList(growable: false),
        equals(
          rebuiltDecoded.roundResults.map((result) {
            return (
              result.roundNumber,
              result.outcome,
              result.abortReason,
              result.finalScore,
            );
          }).toList(growable: false),
        ),
      );
      expect(decoded.entries.length, replay.entries.length);
      expect(decoded.entries.first.accepted, replay.entries.first.accepted);
      expect(
          decoded.entries.first.action.kind, replay.entries.first.action.kind);
    });

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

    test('unsupported replay schema returns typed failure', () {
      final decode = ReplaySession.tryFromMap(
        <String, dynamic>{
          'schemaVersion': 999,
          'engineVersion': 1,
          'seed': 0,
          'roundsPerGame': 3,
          'scoreConfig': <String, dynamic>{
            'pointsTableauToWaste': 5,
            'pointsDrawFromStock': 0,
            'penaltyInvalidAction': 0,
          },
          'roundRulesConfig': <String, dynamic>{'aceKingWrapAround': false},
          'undoConfig': <String, dynamic>{'enabled': true, 'maxSteps': 10},
          'streakConfig': <String, dynamic>{
            'enabled': true,
            'resetOnDraw': true,
            'resetOnInvalidAction': false,
          },
          'entries': <Map<String, dynamic>>[],
        },
      );

      expect(decode.isSuccess, isFalse);
      expect(
        decode.error?.code,
        DecodeFailureCode.unsupportedSchemaVersion,
      );
    });
  });
}
