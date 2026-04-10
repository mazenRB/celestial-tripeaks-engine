import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('TriPeaksGame wrapper', () {
    test('updates state via dispatch', () {
      final game = TriPeaksGame.newGame(seed: 3);
      final before = game.state;

      game.dispatch(const PlayRoundAction(DrawFromStockAction()));

      expect(game.state, isNot(same(before)));
      expect(game.state.stockCount, before.stockCount - 1);
    });
  });

  group('Mode presets', () {
    test('preset ids are stable and parse deterministically', () {
      expect(TriPeaksModePreset.classic.modeId, 'classic');
      expect(TriPeaksModePreset.celestial.modeId, 'celestial');
      expect(
        TriPeaksModePreset.tryParseModeId('classic'),
        TriPeaksModePreset.classic,
      );
      expect(
        TriPeaksModePreset.tryParseModeId('celestial'),
        TriPeaksModePreset.celestial,
      );
      expect(TriPeaksModePreset.tryParseModeId('unknown'), isNull);
    });

    test('classic bundle matches standard solitaire preset', () {
      const bundle = TriPeaksModeBundle.classic;

      expect(bundle.preset, TriPeaksModePreset.classic);
      expect(bundle.ruleset, TriPeaksRuleset.oneRound);
      expect(bundle.scoreConfig.pointsTableauToWaste, 4096);
      expect(bundle.scoreConfig.penaltyInvalidAction, -20000);
      expect(bundle.scoreConfig.allowNegativeTotalScore, isTrue);
      expect(bundle.scoreConfig.resetTimeBonusOnInvalidPenalty, isFalse);
      expect(bundle.scoreConfig.pointsPeakCleared, 200000);
      expect(bundle.scoreConfig.pointsPerRemainingStockCardOnWin, 50000);
      expect(bundle.scoreConfig.multiplierMode, ScoreMultiplierMode.streak);
      expect(
        bundle.roundRulesConfig.toMap(),
        const RoundRulesConfig(
          aceKingWrapAround: false,
          startStockSize: 23,
          stockDecreaseEveryRounds: 999999,
          minStockSize: 23,
        ).toMap(),
      );
      expect(
        bundle.undoConfig.toMap(),
        const UndoConfig(enabled: false, maxSteps: 0).toMap(),
      );
      expect(bundle.streakConfig.toMap(), const StreakConfig().toMap());
      expect(
        bundle.strikeTimerConfig.toMap(),
        const StrikeTimerConfig(enabled: false).toMap(),
      );
      expect(
        bundle.bonusSlotsConfig.toMap(),
        const BonusSlotsConfig(enabled: false).toMap(),
      );
      expect(
        bundle.dealPolicyConfig.toMap(),
        const DealPolicyConfig().toMap(),
      );
    });

    test('celestial bundle is fully populated and distinct', () {
      final bundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );

      expect(bundle.preset, TriPeaksModePreset.celestial);
      expect(bundle.ruleset, TriPeaksRuleset.tenRounds);
      expect(bundle.scoreConfig.pointsTableauToWaste, 4096);
      expect(bundle.scoreConfig.penaltyInvalidAction, -20000);
      expect(bundle.scoreConfig.allowNegativeTotalScore, isFalse);
      expect(bundle.scoreConfig.resetTimeBonusOnInvalidPenalty, isTrue);
      expect(bundle.scoreConfig.pointsPeakCleared, 200000);
      expect(bundle.scoreConfig.pointsPerRemainingStockCardOnWin, 50000);
      expect(bundle.scoreConfig.multiplierMode, ScoreMultiplierMode.timeBonus);
      expect(bundle.roundRulesConfig.minStockSize, 16);
      expect(bundle.roundTimerConfig.enabled, isTrue);
      expect(
        bundle.roundTimerConfig.durationsSecondsByRound,
        equals(<int>[88, 81, 76, 70, 65, 61, 56, 52, 49, 45]),
      );
      expect(bundle.undoConfig.enabled, isFalse);
      expect(bundle.strikeTimerConfig.enabled, isFalse);
      expect(
        bundle.bonusSlotsConfig.spawnPolicy,
        BonusSlotSpawnPolicy.stockTopCard,
      );
      expect(bundle.bonusSlotsConfig.spawnOnOpenSlot2AtStreak, 3);
      expect(bundle.bonusSlotsConfig.spawnOnOpenSlot3AtStreak, 8);
      expect(bundle.dealPolicyConfig.mode, DealPolicyMode.requireSolvable);
      expect(
        bundle.dealPolicyConfig.attemptSeedStrategy,
        AttemptSeedStrategy.fnv1aMix,
      );
      expect(bundle.dealPolicyConfig.maxAttempts, 200);
      expect(bundle.dealPolicyConfig.solverNodeLimit, 300000);
      expect(bundle, isNot(TriPeaksModeBundle.classic));
    });

    test('celestial preset clamps invalid penalties at zero total score', () {
      final bundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );
      final state = TriPeaksState.newGame(
        seed: 21,
        scoreConfig: bundle.scoreConfig,
      );

      final invalid = tryReduceTriPeaks(
        state,
        const RemoveTableauCardAction(99),
      );

      expect(invalid.isSuccess, isFalse);
      expect(invalid.scoreDelta, 0);
      expect(invalid.state.scoreState.totalScore, 0);
      expect(invalid.state.scoreState.lastDelta, 0);
      expect(invalid.scoreBreakdown.totalDelta, 0);
      expect(invalid.scoreBreakdown.invalidPenaltyPoints, 0);
    });

    test('bundle fields can be reused across session replay and match setup',
        () {
      final bundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );
      final session = TriPeaksSessionState.newSession(
        ruleset: bundle.ruleset,
        seed: 42,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        roundTimerConfig: bundle.roundTimerConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
      );
      final replay = TriPeaksReplay.newSession(
        seed: 42,
        ruleset: bundle.ruleset,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        roundTimerConfig: bundle.roundTimerConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
      );
      final match = MatchConfig(
        matchMode: MatchMode.realtime,
        matchId: 'mode-test',
        matchSeed: 42,
        maxPlayers: 2,
        ruleset: bundle.ruleset,
        scoreConfig: bundle.scoreConfig,
        roundRulesConfig: bundle.roundRulesConfig,
        roundTimerConfig: bundle.roundTimerConfig,
        undoConfig: bundle.undoConfig,
        streakConfig: bundle.streakConfig,
        strikeTimerConfig: bundle.strikeTimerConfig,
        bonusSlotsConfig: bundle.bonusSlotsConfig,
        dealPolicyConfig: bundle.dealPolicyConfig,
      );

      expect(session.ruleset, bundle.ruleset);
      expect(session.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(
        session.roundTimerConfig.toMap(),
        bundle.roundTimerConfig.toMap(),
      );
      expect(replay.ruleset, bundle.ruleset);
      expect(replay.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(
        replay.roundTimerConfig.toMap(),
        bundle.roundTimerConfig.toMap(),
      );
      expect(match.ruleset, bundle.ruleset);
      expect(match.scoreConfig.toMap(), bundle.scoreConfig.toMap());
      expect(
        match.roundTimerConfig.toMap(),
        bundle.roundTimerConfig.toMap(),
      );
      expect(
        match.dealPolicyConfig.toMap(),
        bundle.dealPolicyConfig.toMap(),
      );
    });
  });

  group('Daily challenge', () {
    test('preset-backed daily config uses canonical mode ids', () {
      final classic = DailyChallengeConfig.forPreset(
        namespaceId: 'prod',
        preset: TriPeaksModePreset.classic,
      );
      final celestial = DailyChallengeConfig.forPreset(
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );

      expect(classic.modeId, 'classic');
      expect(celestial.modeId, 'celestial');
    });

    test('same date + same config gives same seed and same initial deal', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const date = DateOnly(2026, 2, 20);

      final seedA = dailySeedForDate(date, config);
      final seedB = dailySeedForDate(date, config);
      final gameA = newDailyGame(date, config);
      final gameB = newDailyGame(date, config);

      expect(seedA, seedB);
      expect(gameA.tableau, equals(gameB.tableau));
      expect(gameA.waste, equals(gameB.waste));
      expect(gameA.stock, equals(gameB.stock));
    });

    test('adjacent dates produce different seeds', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const dayA = DateOnly(2026, 2, 20);
      const dayB = DateOnly(2026, 2, 21);

      final seedA = dailySeedForDate(dayA, config);
      final seedB = dailySeedForDate(dayB, config);

      expect(seedA, isNot(seedB));
    });

    test('namespaceId and modeId influence daily seed', () {
      const date = DateOnly(2026, 2, 20);
      const base = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const otherNamespace = DailyChallengeConfig(
        namespaceId: 'staging',
        modeId: 'classic',
        schemaVersion: 1,
      );
      const otherMode = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'hard',
        schemaVersion: 1,
      );

      final baseSeed = dailySeedForDate(date, base);
      final namespaceSeed = dailySeedForDate(date, otherNamespace);
      final modeSeed = dailySeedForDate(date, otherMode);

      expect(baseSeed, isNot(namespaceSeed));
      expect(baseSeed, isNot(modeSeed));
    });

    test('seed derivation uses provided date only (timezone-independent)', () {
      const config = DailyChallengeConfig(
        namespaceId: 'prod',
        modeId: 'classic',
      );
      final fromUtc = DateOnly.fromDateTime(DateTime.utc(2026, 2, 20, 23, 59));
      const explicit = DateOnly(2026, 2, 20);

      final utcSeed = dailySeedForDate(fromUtc, config);
      final explicitSeed = dailySeedForDate(explicit, config);

      expect(utcSeed, explicitSeed);
    });

    test('preset-backed daily helpers apply resolved bundles', () {
      const date = DateOnly(2026, 2, 20);
      final classicBundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.classic,
      );
      final celestialBundle = TriPeaksModeBundle.forPreset(
        TriPeaksModePreset.celestial,
      );
      final classicSession = newDailySessionForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.classic,
      );
      final session = newDailySessionForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );
      final game = newDailyGameForPreset(
        date,
        namespaceId: 'prod',
        preset: TriPeaksModePreset.celestial,
      );

      expect(
        classicSession.ruleset.roundsPerGame,
        classicBundle.ruleset.roundsPerGame,
      );
      expect(
        session.ruleset.roundsPerGame,
        celestialBundle.ruleset.roundsPerGame,
      );
      expect(
        session.scoreConfig.toMap(),
        celestialBundle.scoreConfig.toMap(),
      );
      expect(
        session.roundRulesConfig.toMap(),
        celestialBundle.roundRulesConfig.toMap(),
      );
      expect(session.undoConfig.toMap(), celestialBundle.undoConfig.toMap());
      expect(
        session.strikeTimerConfig.toMap(),
        celestialBundle.strikeTimerConfig.toMap(),
      );
      expect(game.scoreConfig.toMap(), celestialBundle.scoreConfig.toMap());
      expect(
        game.roundRulesConfig.toMap(),
        celestialBundle.roundRulesConfig.toMap(),
      );
    });
  });
}
