import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Parity baseline guardrails', () {
    test('deterministic fingerprint fixture remains stable', () {
      final state = TriPeaksState.newGame(seed: 42);
      expect(stateFingerprint(state), '8614e617');
    });

    test('scoring breakdown invariants remain exact', () {
      final initial = TriPeaksState.newGame(seed: 9);
      final accepted = tryReduceTriPeaks(
        initial,
        const DrawFromStockAction(),
      );
      expect(accepted.isSuccess, isTrue);
      final breakdown = accepted.state.scoreState.lastBreakdown;
      expect(
        breakdown.totalDelta,
        breakdown.tableauBasePoints +
            breakdown.multiplierExtraPoints +
            breakdown.peakBonusPoints +
            breakdown.drawPoints +
            breakdown.invalidPenaltyPoints +
            breakdown.endRoundRemainingStockBonusPoints,
      );
      expect(breakdown.totalDelta, accepted.state.scoreState.lastDelta);
    });

    test('bonus policy serialization stays stable across policies', () {
      for (final policy in BonusSlotSpawnPolicy.values) {
        final config = BonusSlotsConfig(spawnPolicy: policy);
        final decoded = BonusSlotsConfig.tryFromMap(config.toMap());
        expect(decoded.isSuccess, isTrue);
        expect(decoded.value!.spawnPolicy, policy);
      }
    });

    test('undo restores prior score breakdown and multiplier exactly', () {
      var state = TriPeaksState.newGame(
        seed: 3,
        undoConfig: const UndoConfig(maxSteps: 5),
      );
      final before = state;
      state = reduceTriPeaks(state, const DrawFromStockAction());
      state = reduceTriPeaks(state, const UndoAction());

      expect(state.scoreState.lastBreakdown.toMap(),
          before.scoreState.lastBreakdown.toMap());
      expect(state.scoreState.currentMultiplier,
          before.scoreState.currentMultiplier);
      expect(state.scoreState.lastDelta, before.scoreState.lastDelta);
      expect(state.stock, before.stock);
    });

    test('replay reconstruction parity is deterministic', () {
      var live = TriPeaksSessionState.newSession(
        ruleset: TriPeaksRuleset.threeRounds,
        seed: 17,
      );
      var replay = TriPeaksReplay.newSession(
        seed: 17,
        ruleset: TriPeaksRuleset.threeRounds,
      );
      for (var i = 0; i < 4; i++) {
        final action = i.isEven
            ? const PlayRoundAction(DrawFromStockAction())
            : const PlayRoundAction(UseBonusSlotAction(1));
        final recorded = recordAction(replay, live, action);
        replay = recorded.replay;
        live = recorded.state;
      }

      final rebuilt = replayToState(replay);
      expect(sessionFingerprint(rebuilt), sessionFingerprint(live));
      expect(rebuilt.currentRound.stock, live.currentRound.stock);
      expect(rebuilt.currentRound.scoreState.toMap(),
          live.currentRound.scoreState.toMap());
    });

    test('match reducer and replay are deterministic for same events', () {
      final config = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'parity',
        matchSeed: 77,
        maxPlayers: 2,
      );
      final events = <MatchEvent>[
        const JoinMatchEvent(playerId: 'p1'),
        const JoinMatchEvent(playerId: 'p2'),
        const StartMatchEvent(),
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(DrawFromStockAction()),
        ),
      ];

      final a = replayMatchEvents(MatchState.newMatch(config: config), events);
      final b = replayMatchEvents(MatchState.newMatch(config: config), events);
      expect(a.toMap(), b.toMap());
      expect(a.authoritativeSequence, b.authoritativeSequence);
    });
  });
}
