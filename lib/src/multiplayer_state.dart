import 'dart:convert';

import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

import 'multiplayer_config.dart';
import 'multiplayer_player_state.dart';

/// Current lifecycle stage for the synchronized match.
enum MatchPhase { playing, intermission, finished }

final class MatchState {
  MatchState._({
    required this.config,
    required this.phase,
    required this.currentRoundNumber,
    required this.players,
    required this.intermissionRemainingSeconds,
    required this.intermissionDeadlineToken,
    required this.skipVotes,
    required this.asyncDeadlineRemainingSeconds,
    required this.asyncDeadlineToken,
    required this.finishedByDeadline,
  });

  /// Creates an initial match with the configured fixed roster.
  factory MatchState.newMatch({required MatchConfig config}) {
    final fixedConfig = config.copyWith(
      playerIds: List<String>.unmodifiable(config.playerIds),
      roundTimerConfig: RoundTimerConfig(
        enabled: config.roundTimerConfig.enabled,
        durationsSecondsByRound: List<int>.unmodifiable(
          config.roundTimerConfig.durationsSecondsByRound,
        ),
      ),
    );
    _validateConfig(fixedConfig);
    final players = <MatchPlayerState>[];
    final deal = newGameWithDealPolicy(
      fixedConfig.matchSeed,
      scoreConfig: fixedConfig.scoreConfig,
      roundRulesConfig: fixedConfig.roundRulesConfig,
      roundTimerConfig: fixedConfig.roundTimerConfig,
      undoConfig: fixedConfig.undoConfig,
      streakConfig: fixedConfig.streakConfig,
      strikeTimerConfig: fixedConfig.strikeTimerConfig,
      bonusSlotsConfig: fixedConfig.bonusSlotsConfig,
      dealPolicy: fixedConfig.dealPolicyConfig,
    );
    if (!deal.isSuccess || deal.attemptSeed == null) {
      throw StateError(deal.failure?.message ?? 'Unable to create match deal.');
    }
    final effectiveSeed = deal.attemptSeed!;
    for (final playerId in fixedConfig.playerIds) {
      var session = TriPeaksSessionState.newSession(
        ruleset: fixedConfig.ruleset,
        seed: effectiveSeed,
        scoreConfig: fixedConfig.scoreConfig,
        roundRulesConfig: fixedConfig.roundRulesConfig,
        roundTimerConfig: fixedConfig.roundTimerConfig,
        undoConfig: fixedConfig.undoConfig,
        streakConfig: fixedConfig.streakConfig,
        strikeTimerConfig: fixedConfig.strikeTimerConfig,
        bonusSlotsConfig: fixedConfig.bonusSlotsConfig,
      );
      var replay = ReplaySession.newSession(
        seed: effectiveSeed,
        ruleset: fixedConfig.ruleset,
        scoreConfig: fixedConfig.scoreConfig,
        roundRulesConfig: fixedConfig.roundRulesConfig,
        roundTimerConfig: fixedConfig.roundTimerConfig,
        undoConfig: fixedConfig.undoConfig,
        streakConfig: fixedConfig.streakConfig,
        strikeTimerConfig: fixedConfig.strikeTimerConfig,
        bonusSlotsConfig: fixedConfig.bonusSlotsConfig,
      );
      if (fixedConfig.matchMode == MatchMode.live) {
        final started = recordAction(
          replay,
          session,
          const PlayRoundAction(StartRoundTimerAction()),
        );
        if (!started.reduceResult.isSuccess) {
          throw StateError(started.reduceResult.roundError?.message ??
              'Unable to start live round timer.');
        }
        session = started.state;
        replay = started.replay;
      }
      players.add(
        MatchPlayerState(
          playerId: playerId,
          session: session,
          replay: replay,
        ),
      );
    }
    return MatchState._(
      config: fixedConfig,
      phase: MatchPhase.playing,
      currentRoundNumber: 1,
      players: List<MatchPlayerState>.unmodifiable(players),
      intermissionRemainingSeconds: 0,
      intermissionDeadlineToken: 0,
      skipVotes: const <String>{},
      asyncDeadlineRemainingSeconds:
          fixedConfig.matchMode == MatchMode.asynchronous
              ? fixedConfig.asyncDeadlineSeconds
              : null,
      asyncDeadlineToken: 1,
      finishedByDeadline: false,
    );
  }

  /// Match configuration and fixed roster.
  final MatchConfig config;

  /// Shared round currently active for the room.
  final int currentRoundNumber;

  /// Current match lifecycle stage.
  final MatchPhase phase;

  /// Independent player states in roster order.
  final List<MatchPlayerState> players;

  /// Remaining live intermission seconds, or zero outside intermission.
  final int intermissionRemainingSeconds;

  /// Token for the current live intermission timer.
  final int intermissionDeadlineToken;

  /// Participants who voted to skip the current intermission.
  final Set<String> skipVotes;

  /// Remaining async deadline seconds, or `null` when disabled/inapplicable.
  final int? asyncDeadlineRemainingSeconds;

  /// Token for the asynchronous match deadline.
  final int asyncDeadlineToken;

  /// Whether an asynchronous match ended at its deadline.
  final bool finishedByDeadline;

  /// Serializes the full match state and nested player sessions.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_match_state',
        'config': config.toMap(),
        'phase': phase.name,
        'currentRoundNumber': currentRoundNumber,
        'players': players.map((player) => player.toMap()).toList(),
        'intermissionRemainingSeconds': intermissionRemainingSeconds,
        'intermissionDeadlineToken': intermissionDeadlineToken,
        'skipVotes': skipVotes.toList()..sort(),
        'asyncDeadlineRemainingSeconds': asyncDeadlineRemainingSeconds,
        'asyncDeadlineToken': asyncDeadlineToken,
        'finishedByDeadline': finishedByDeadline,
      };

  /// Decodes a full match snapshot with typed failure details.
  static DecodeResult<MatchState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<MatchState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported multiplayer match schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_match_state') {
      return const DecodeResult<MatchState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown multiplayer match type.',
        ),
      );
    }
    try {
      final configResult = MatchConfig.tryFromMap(
        map['config'] as Map<String, dynamic>,
      );
      if (!configResult.isSuccess) {
        return DecodeResult.failure(configResult.error!);
      }
      final rawPlayers = map['players'] as List<dynamic>;
      final players = <MatchPlayerState>[];
      for (final raw in rawPlayers) {
        final decoded = MatchPlayerState.tryFromMap(
          raw as Map<String, dynamic>,
        );
        if (!decoded.isSuccess) return DecodeResult.failure(decoded.error!);
        players.add(decoded.value!);
      }
      final rawVotes = map['skipVotes'] as List<dynamic>? ?? const [];
      final currentRoundNumber = map['currentRoundNumber'];
      final remaining = map['intermissionRemainingSeconds'];
      final intermissionToken = map['intermissionDeadlineToken'];
      final asyncRemaining = map['asyncDeadlineRemainingSeconds'];
      final asyncToken = map['asyncDeadlineToken'];
      if (currentRoundNumber is! int ||
          remaining is! int ||
          intermissionToken is! int ||
          (asyncRemaining != null && asyncRemaining is! int) ||
          asyncToken is! int) {
        throw const FormatException('Invalid multiplayer timer state.');
      }
      final state = MatchState._(
        config: configResult.value!,
        phase: MatchPhase.values.byName(map['phase'] as String),
        currentRoundNumber: currentRoundNumber,
        players: List<MatchPlayerState>.unmodifiable(players),
        intermissionRemainingSeconds: remaining,
        intermissionDeadlineToken: intermissionToken,
        skipVotes: Set<String>.unmodifiable(rawVotes.cast<String>()),
        asyncDeadlineRemainingSeconds: asyncRemaining as int?,
        asyncDeadlineToken: asyncToken,
        finishedByDeadline: map['finishedByDeadline'] as bool? ?? false,
      );
      _validateConfig(state.config);
      _validateMatchPlayers(state);
      if (state.currentRoundNumber < 1 ||
          state.currentRoundNumber > state.config.ruleset.roundsPerGame ||
          state.intermissionRemainingSeconds < 0 ||
          state.intermissionDeadlineToken < 0 ||
          state.asyncDeadlineToken < 0 ||
          (state.asyncDeadlineRemainingSeconds != null &&
              state.asyncDeadlineRemainingSeconds! < 0) ||
          !state.config.playerIds.toSet().containsAll(state.skipVotes)) {
        throw const FormatException('Invalid multiplayer lifecycle values.');
      }
      if (state.config.matchMode == MatchMode.live &&
          (state.asyncDeadlineRemainingSeconds != null ||
              state.finishedByDeadline)) {
        throw const FormatException('Live match has Async deadline state.');
      }
      if (state.config.matchMode == MatchMode.asynchronous &&
          (state.phase == MatchPhase.intermission ||
              state.skipVotes.isNotEmpty ||
              (state.phase == MatchPhase.finished &&
                  state.asyncDeadlineRemainingSeconds != null))) {
        throw const FormatException('Async match has invalid Live state.');
      }
      if (state.phase == MatchPhase.intermission &&
          (state.config.matchMode != MatchMode.live ||
              state.intermissionRemainingSeconds == 0 ||
              !state.players.every(
                (player) =>
                    player.session.roundsCompleted == state.currentRoundNumber,
              ))) {
        throw const FormatException('Invalid Live intermission state.');
      }
      if (state.phase != MatchPhase.intermission &&
          state.skipVotes.isNotEmpty) {
        throw const FormatException('Skip votes exist outside intermission.');
      }
      return DecodeResult.success(state);
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid multiplayer match payload: $error',
        ),
      );
    }
  }

  /// Returns a match state copy with selected lifecycle values replaced.
  MatchState copyWith({
    MatchPhase? phase,
    int? currentRoundNumber,
    List<MatchPlayerState>? players,
    int? intermissionRemainingSeconds,
    int? intermissionDeadlineToken,
    Set<String>? skipVotes,
    int? asyncDeadlineRemainingSeconds,
    bool clearAsyncDeadline = false,
    int? asyncDeadlineToken,
    bool? finishedByDeadline,
  }) {
    final updated = MatchState._(
      config: config,
      phase: phase ?? this.phase,
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      players: List<MatchPlayerState>.unmodifiable(players ?? this.players),
      intermissionRemainingSeconds:
          intermissionRemainingSeconds ?? this.intermissionRemainingSeconds,
      intermissionDeadlineToken:
          intermissionDeadlineToken ?? this.intermissionDeadlineToken,
      skipVotes: Set<String>.unmodifiable(skipVotes ?? this.skipVotes),
      asyncDeadlineRemainingSeconds: clearAsyncDeadline
          ? null
          : asyncDeadlineRemainingSeconds ?? this.asyncDeadlineRemainingSeconds,
      asyncDeadlineToken: asyncDeadlineToken ?? this.asyncDeadlineToken,
      finishedByDeadline: finishedByDeadline ?? this.finishedByDeadline,
    );
    if (players != null) {
      try {
        _validateMatchPlayers(updated);
      } on Object catch (error) {
        throw ArgumentError.value(players, 'players', '$error');
      }
    }
    return updated;
  }
}

MatchState copyMatchStateForReducer(
  MatchState state,
  List<MatchPlayerState> players,
) {
  return MatchState._(
    config: state.config,
    phase: state.phase,
    currentRoundNumber: state.currentRoundNumber,
    players: players,
    intermissionRemainingSeconds: state.intermissionRemainingSeconds,
    intermissionDeadlineToken: state.intermissionDeadlineToken,
    skipVotes: state.skipVotes,
    asyncDeadlineRemainingSeconds: state.asyncDeadlineRemainingSeconds,
    asyncDeadlineToken: state.asyncDeadlineToken,
    finishedByDeadline: state.finishedByDeadline,
  );
}

void _validateMatchPlayers(MatchState state) {
  final playerIds = state.players.map((player) => player.playerId).toSet();
  if (playerIds.length != state.config.playerIds.length ||
      !state.players.every(
        (player) => state.config.playerIds.contains(player.playerId),
      )) {
    throw const FormatException('Match snapshot roster mismatch.');
  }
  _validatePlayerReplays(state);
}

void _validatePlayerReplays(MatchState state) {
  final config = state.config;
  final deal = newGameWithDealPolicy(
    config.matchSeed,
    scoreConfig: config.scoreConfig,
    roundRulesConfig: config.roundRulesConfig,
    roundTimerConfig: config.roundTimerConfig,
    undoConfig: config.undoConfig,
    streakConfig: config.streakConfig,
    strikeTimerConfig: config.strikeTimerConfig,
    bonusSlotsConfig: config.bonusSlotsConfig,
    dealPolicy: config.dealPolicyConfig,
  );
  final expectedSeed = deal.attemptSeed;
  if (!deal.isSuccess || expectedSeed == null) {
    throw const FormatException('Match configuration has no valid deal.');
  }

  for (final player in state.players) {
    final replay = player.replay;
    if (player.session.seed != expectedSeed || replay.seed != expectedSeed) {
      throw const FormatException('Player state does not use the match seed.');
    }
    if (!_sameMap(replay.ruleset.toMap(), config.ruleset.toMap()) ||
        !_sameMap(replay.scoreConfig.toMap(), config.scoreConfig.toMap()) ||
        !_sameMap(
          replay.roundRulesConfig.toMap(),
          config.roundRulesConfig.toMap(),
        ) ||
        !_sameMap(
          replay.roundTimerConfig.toMap(),
          config.roundTimerConfig.toMap(),
        ) ||
        !_sameMap(replay.undoConfig.toMap(), config.undoConfig.toMap()) ||
        !_sameMap(replay.streakConfig.toMap(), config.streakConfig.toMap()) ||
        !_sameMap(
          replay.strikeTimerConfig.toMap(),
          config.strikeTimerConfig.toMap(),
        ) ||
        !_sameMap(
          replay.bonusSlotsConfig.toMap(),
          config.bonusSlotsConfig.toMap(),
        )) {
      throw const FormatException('Player replay uses different match rules.');
    }
    if (replayFingerprint(replay) != sessionFingerprint(player.session)) {
      throw const FormatException('Player session and replay do not match.');
    }
  }
}

bool _sameMap(Map<String, dynamic> left, Map<String, dynamic> right) {
  return jsonEncode(left) == jsonEncode(right);
}

void _validateConfig(MatchConfig config) {
  if (config.matchId.trim().isEmpty || config.playerIds.length < 2) {
    throw ArgumentError('A match needs an id and at least two players.');
  }
  if (config.playerIds.any((id) => id.trim().isEmpty) ||
      config.playerIds.toSet().length != config.playerIds.length) {
    throw ArgumentError('Player ids must be unique and non-empty.');
  }
  if (config.matchMode == MatchMode.asynchronous &&
      config.playerIds.length != 2) {
    throw ArgumentError('Asynchronous matches are strictly 1v1.');
  }
  if (config.matchMode == MatchMode.live) {
    final timer = config.roundTimerConfig;
    if (!timer.enabled ||
        timer.durationsSecondsByRound.length != config.ruleset.roundsPerGame ||
        timer.durationsSecondsByRound.any((seconds) => seconds <= 0)) {
      throw ArgumentError(
        'Live matches need an enabled timer for every configured round.',
      );
    }
    if (config.intermissionDurationSeconds <= 0) {
      throw ArgumentError('Intermission duration must be positive.');
    }
    if (config.skipVoteThreshold <= 0 || config.skipVoteThreshold > 1) {
      throw ArgumentError('Skip vote threshold must be in (0, 1].');
    }
  }
  if (config.asyncDeadlineSeconds case final deadline?) {
    if (deadline <= 0) throw ArgumentError('Async deadline must be positive.');
  }
}
