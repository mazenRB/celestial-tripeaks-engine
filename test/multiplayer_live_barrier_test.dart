import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('live multiplayer rounds', () {
    MatchConfig config({
      RoundTimerConfig? timer,
      double skipVoteThreshold = 1,
      List<String> playerIds = const <String>['p1', 'p2'],
    }) =>
        MatchConfig(
          matchMode: MatchMode.live,
          matchId: 'live-1',
          matchSeed: 123,
          playerIds: playerIds,
          ruleset: TriPeaksRuleset.threeRounds,
          roundTimerConfig: timer ??
              const RoundTimerConfig(
                enabled: true,
                durationsSecondsByRound: <int>[30, 25, 20],
              ),
          skipVoteThreshold: skipVoteThreshold,
        );

    test('starts existing timer preset on each independent session', () {
      final match = MatchState.newMatch(config: config());

      expect(match.phase, MatchPhase.playing);
      expect(match.players, hasLength(2));
      for (final player in match.players) {
        expect(player.session.seed, 123);
        expect(player.session.currentRound.roundTimerState.isStarted, isTrue);
        expect(
          player.session.currentRound.roundTimerState.remainingSeconds,
          30,
        );
      }
      expect(
        identical(match.players[0].session, match.players[1].session),
        isFalse,
      );
    });

    test('accepts the engine celestial preset timer schedule as configured',
        () {
      final preset = TriPeaksModeBundle.celestial;
      final match = MatchState.newMatch(
        config: MatchConfig(
          matchMode: MatchMode.live,
          matchId: 'live-preset',
          matchSeed: 321,
          playerIds: const <String>['p1', 'p2'],
          ruleset: preset.ruleset,
          scoreConfig: preset.scoreConfig,
          roundRulesConfig: preset.roundRulesConfig,
          roundTimerConfig: preset.roundTimerConfig,
          undoConfig: preset.undoConfig,
          streakConfig: preset.streakConfig,
          strikeTimerConfig: preset.strikeTimerConfig,
          bonusSlotsConfig: preset.bonusSlotsConfig,
          dealPolicyConfig: preset.dealPolicyConfig,
        ),
      );

      expect(
        match.players.first.session.currentRound.roundTimerState
            .remainingSeconds,
        preset.roundTimerConfig.durationsSecondsByRound.first,
      );
    });

    test('match snapshots freeze caller-owned roster and timer lists', () {
      final playerIds = <String>['p1', 'p2'];
      final durations = <int>[30, 25, 20];
      final match = MatchState.newMatch(
        config: MatchConfig(
          matchMode: MatchMode.live,
          matchId: 'live-frozen',
          matchSeed: 55,
          playerIds: playerIds,
          roundTimerConfig: RoundTimerConfig(
            enabled: true,
            durationsSecondsByRound: durations,
          ),
        ),
      );

      playerIds[0] = 'replaced';
      durations[0] = 0;

      expect(match.config.playerIds, <String>['p1', 'p2']);
      expect(
        match.config.roundTimerConfig.durationsSecondsByRound,
        <int>[30, 25, 20],
      );
    });

    test('waits for every player then opens configurable skip intermission',
        () {
      final initial = MatchState.newMatch(
        config: config().copyWith(intermissionDurationSeconds: 15),
      );
      final afterFirst = tryReduceMatch(
        initial,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: AbortRoundAction(),
        ),
      );

      expect(afterFirst.isSuccess, isTrue);
      expect(afterFirst.state.phase, MatchPhase.playing);
      expect(afterFirst.state.currentRoundNumber, 1);
      expect(afterFirst.state.players[0].session.roundsCompleted, 1);
      expect(
        afterFirst
            .state.players[0].session.currentRound.roundTimerState.isStarted,
        isFalse,
      );
      expect(afterFirst.state.players[1].session.roundsCompleted, 0);
      expect(
        tryReduceMatch(
          afterFirst.state,
          const SubmitMatchActionEvent(
            playerId: 'p1',
            action: PlayRoundAction(DrawFromStockAction()),
          ),
        ).isSuccess,
        isFalse,
      );

      final afterSecond = tryReduceMatch(
        afterFirst.state,
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: AbortRoundAction(),
        ),
      );

      expect(afterSecond.isSuccess, isTrue);
      expect(afterSecond.state.phase, MatchPhase.intermission);
      expect(afterSecond.state.intermissionRemainingSeconds, 15);
      expect(
        afterSecond.state.players.every(
          (player) => player.session.currentRoundNumber == 2,
        ),
        isTrue,
      );

      final skipped = tryReduceMatch(
        afterSecond.state,
        const VoteToSkipLiveIntermissionEvent(playerId: 'p1'),
      );
      expect(skipped.isSuccess, isTrue);
      expect(skipped.state.phase, MatchPhase.intermission);

      final advanced = tryReduceMatch(
        skipped.state,
        const VoteToSkipLiveIntermissionEvent(playerId: 'p2'),
      );
      expect(advanced.isSuccess, isTrue, reason: advanced.failure?.message);
      expect(advanced.state.phase, MatchPhase.playing);
      expect(
        advanced.state.players.every(
          (player) => player.session.currentRoundNumber == 2,
        ),
        isTrue,
      );
      expect(
        advanced.state.players.every(
          (player) =>
              player.session.currentRound.roundTimerState.remainingSeconds ==
              25,
        ),
        isTrue,
      );
    });

    test('advances when intermission expires without skip votes', () {
      var match = MatchState.newMatch(config: config());
      final timeout = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: PlayRoundAction(
            AdvanceRoundTimerAction(elapsedSeconds: 30, deadlineToken: 1),
          ),
        ),
      );
      expect(timeout.isSuccess, isTrue);
      expect(timeout.state.players[0].session.roundsTimedOut, 1);
      match = timeout.state;

      for (final playerId in const <String>['p2']) {
        match = tryReduceMatch(
          match,
          SubmitMatchActionEvent(
            playerId: playerId,
            action: const AbortRoundAction(),
          ),
        ).state;
      }
      expect(match.phase, MatchPhase.intermission);

      final advanced = tryReduceMatch(
        match,
        AdvanceLiveIntermissionEvent(
          elapsedSeconds: 15,
          deadlineToken: match.intermissionDeadlineToken,
        ),
      );

      expect(advanced.isSuccess, isTrue, reason: advanced.failure?.message);
      expect(advanced.state.phase, MatchPhase.playing);
      expect(advanced.state.players.first.session.currentRoundNumber, 2);
    });

    test('copyWith rejects a session that its replay cannot reproduce', () {
      final matchConfig = config().copyWith(
        roundRulesConfig: const RoundRulesConfig(
          startStockSize: 23,
          stockDecreaseEveryRounds: 100,
          minStockSize: 23,
        ),
      );
      final initial = MatchState.newMatch(config: matchConfig);
      final lostSession = TriPeaksSessionState.newSession(
        ruleset: matchConfig.ruleset,
        seed: matchConfig.matchSeed,
        roundDecks: <List<Card>>[
          buildAlwaysLostDeck(waste: const Card(Rank.ace, Suit.clubs)),
          buildAlwaysLostDeck(waste: const Card(Rank.king, Suit.clubs)),
          buildAlwaysLostDeck(waste: const Card(Rank.queen, Suit.clubs)),
        ],
        scoreConfig: matchConfig.scoreConfig,
        roundRulesConfig: matchConfig.roundRulesConfig,
        roundTimerConfig: matchConfig.roundTimerConfig,
        undoConfig: matchConfig.undoConfig,
        streakConfig: matchConfig.streakConfig,
        strikeTimerConfig: matchConfig.strikeTimerConfig,
        bonusSlotsConfig: matchConfig.bonusSlotsConfig,
      );
      var session = lostSession;
      var replay = ReplaySession.newSession(
        seed: matchConfig.matchSeed,
        ruleset: matchConfig.ruleset,
        scoreConfig: matchConfig.scoreConfig,
        roundRulesConfig: matchConfig.roundRulesConfig,
        roundTimerConfig: matchConfig.roundTimerConfig,
        undoConfig: matchConfig.undoConfig,
        streakConfig: matchConfig.streakConfig,
        strikeTimerConfig: matchConfig.strikeTimerConfig,
        bonusSlotsConfig: matchConfig.bonusSlotsConfig,
      );
      final started = recordAction(
        replay,
        session,
        const PlayRoundAction(StartRoundTimerAction()),
      );
      session = started.state;
      replay = started.replay;

      while (session.currentRound.canDrawFromStock) {
        final step = recordAction(
          replay,
          session,
          const PlayRoundAction(DrawFromStockAction()),
        );
        expect(step.reduceResult.isSuccess, isTrue);
        session = step.state;
        replay = step.replay;
      }
      expect(session.currentRound.isLost, isTrue);
      expect(session.roundsLost, 1);

      final players = <MatchPlayerState>[
        MatchPlayerState(playerId: 'p1', session: session, replay: replay),
        initial.players[1],
      ];
      expect(
        () => initial.copyWith(players: players),
        throwsArgumentError,
      );
    });

    test('rejects live matches without an enabled timer for every round', () {
      expect(
        () => MatchState.newMatch(
          config: config(
            timer: const RoundTimerConfig(
              enabled: true,
              durationsSecondsByRound: <int>[30, 0, 20],
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('configurable vote fraction can advance before unanimity', () {
      final initial = MatchState.newMatch(
        config: config(skipVoteThreshold: 0.5),
      );
      var match = tryReduceMatch(
        initial,
        const SubmitMatchActionEvent(
          playerId: 'p1',
          action: AbortRoundAction(),
        ),
      ).state;
      match = tryReduceMatch(
        match,
        const SubmitMatchActionEvent(
          playerId: 'p2',
          action: AbortRoundAction(),
        ),
      ).state;

      final advanced = tryReduceMatch(
        match,
        const VoteToSkipLiveIntermissionEvent(playerId: 'p1'),
      );

      expect(advanced.isSuccess, isTrue);
      expect(advanced.state.phase, MatchPhase.playing);
      expect(advanced.state.currentRoundNumber, 2);
    });

    test('intermission updates rotate timer tokens and reject duplicates', () {
      var match = MatchState.newMatch(config: config());
      for (final playerId in const <String>['p1', 'p2']) {
        match = tryReduceMatch(
          match,
          SubmitMatchActionEvent(
            playerId: playerId,
            action: const AbortRoundAction(),
          ),
        ).state;
      }
      final originalToken = match.intermissionDeadlineToken;
      final partial = tryReduceMatch(
        match,
        AdvanceLiveIntermissionEvent(
          elapsedSeconds: 8,
          deadlineToken: originalToken,
        ),
      );
      expect(partial.isSuccess, isTrue);
      expect(partial.state.intermissionRemainingSeconds, 7);
      expect(partial.state.intermissionDeadlineToken, originalToken + 1);

      final duplicate = tryReduceMatch(
        partial.state,
        AdvanceLiveIntermissionEvent(
          elapsedSeconds: 8,
          deadlineToken: originalToken,
        ),
      );
      expect(duplicate.isSuccess, isFalse);
      expect(duplicate.state.intermissionRemainingSeconds, 7);
    });
  });
}
