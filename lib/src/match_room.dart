part of '../tripeaks_engine.dart';

/// Multiplayer match mode.
enum MatchMode {
  realtime,
  async,
}

/// Match lifecycle status.
enum MatchStatus {
  waiting,
  active,
  finished,
}

/// Per-player lifecycle status.
enum PlayerStatus {
  joined,
  active,
  finished,
  left,
}

/// Deterministic multiplayer match configuration.
final class MatchConfig {
  /// Creates a match config.
  const MatchConfig({
    required this.matchMode,
    required this.matchId,
    required this.matchSeed,
    required this.maxPlayers,
    this.ruleset = TriPeaksRuleset.threeRounds,
    this.scoreConfig = const ScoreConfig(),
    this.roundRulesConfig = const RoundRulesConfig(),
    this.undoConfig = const UndoConfig(),
    this.streakConfig = const StreakConfig(),
    this.strikeTimerConfig = const StrikeTimerConfig(),
    this.bonusSlotsConfig = const BonusSlotsConfig(),
    this.dealPolicyConfig = const DealPolicyConfig(),
    this.engineVersion = 1,
  }) : assert(maxPlayers > 0);

  /// Match mode.
  final MatchMode matchMode;

  /// Stable match identifier.
  final String matchId;

  /// Shared match seed for fair equivalent deals.
  final int matchSeed;

  /// Maximum number of players.
  final int maxPlayers;

  /// Shared session ruleset.
  final TriPeaksRuleset ruleset;

  /// Shared score config.
  final ScoreConfig scoreConfig;

  /// Shared round mechanics config.
  final RoundRulesConfig roundRulesConfig;

  /// Shared undo config.
  final UndoConfig undoConfig;

  /// Shared streak config.
  final StreakConfig streakConfig;

  /// Shared strike timer config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Shared bonus-slots config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Shared deal policy config.
  final DealPolicyConfig dealPolicyConfig;

  /// Engine version metadata.
  final int engineVersion;

  /// Serializes config to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_config',
      'matchMode': matchMode.name,
      'matchId': matchId,
      'matchSeed': matchSeed,
      'maxPlayers': maxPlayers,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'dealPolicyConfig': dealPolicyConfig.toMap(),
      'engineVersion': engineVersion,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<MatchConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final rulesetMap = map['ruleset'];
    final scoreMap = map['scoreConfig'];
    final roundRulesMap = map['roundRulesConfig'];
    final undoMap = map['undoConfig'];
    final streakMap = map['streakConfig'];
    final strikeTimerMap = map['strikeTimerConfig'];
    final bonusSlotsMap = map['bonusSlotsConfig'];
    final dealPolicyMap = map['dealPolicyConfig'];
    if (rulesetMap is! Map<String, dynamic> ||
        scoreMap is! Map<String, dynamic> ||
        roundRulesMap is! Map<String, dynamic> ||
        undoMap is! Map<String, dynamic> ||
        streakMap is! Map<String, dynamic> ||
        strikeTimerMap is! Map<String, dynamic> ||
        bonusSlotsMap is! Map<String, dynamic> ||
        dealPolicyMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid nested match config payload.',
        ),
      );
    }

    final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!rulesetResult.isSuccess) {
      return DecodeResult.failure(rulesetResult.error!);
    }
    final scoreResult = ScoreConfig.tryFromMap(scoreMap);
    if (!scoreResult.isSuccess) {
      return DecodeResult.failure(scoreResult.error!);
    }
    final roundRulesResult = RoundRulesConfig.tryFromMap(roundRulesMap);
    if (!roundRulesResult.isSuccess) {
      return DecodeResult.failure(roundRulesResult.error!);
    }
    final undoResult = UndoConfig.tryFromMap(undoMap);
    if (!undoResult.isSuccess) {
      return DecodeResult.failure(undoResult.error!);
    }
    final streakResult = StreakConfig.tryFromMap(streakMap);
    if (!streakResult.isSuccess) {
      return DecodeResult.failure(streakResult.error!);
    }
    final strikeTimerResult = StrikeTimerConfig.tryFromMap(strikeTimerMap);
    if (!strikeTimerResult.isSuccess) {
      return DecodeResult.failure(strikeTimerResult.error!);
    }
    final bonusSlotsResult = BonusSlotsConfig.tryFromMap(bonusSlotsMap);
    if (!bonusSlotsResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsResult.error!);
    }
    final dealPolicyResult = DealPolicyConfig.tryFromMap(dealPolicyMap);
    if (!dealPolicyResult.isSuccess) {
      return DecodeResult.failure(dealPolicyResult.error!);
    }

    final modeName = map['matchMode'];
    final matchId = map['matchId'];
    final matchSeed = map['matchSeed'];
    final maxPlayers = map['maxPlayers'];
    final engineVersion = map['engineVersion'];
    if (modeName is! String ||
        matchId is! String ||
        matchSeed is! int ||
        maxPlayers is! int ||
        engineVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid primitive match config fields.',
        ),
      );
    }

    try {
      return DecodeResult.success(
        MatchConfig(
          matchMode: MatchMode.values.byName(modeName),
          matchId: matchId,
          matchSeed: matchSeed,
          maxPlayers: maxPlayers,
          ruleset: rulesetResult.value!,
          scoreConfig: scoreResult.value!,
          roundRulesConfig: roundRulesResult.value!,
          undoConfig: undoResult.value!,
          streakConfig: streakResult.value!,
          strikeTimerConfig: strikeTimerResult.value!,
          bonusSlotsConfig: bonusSlotsResult.value!,
          dealPolicyConfig: dealPolicyResult.value!,
          engineVersion: engineVersion,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match config payload: $error',
        ),
      );
    }
  }
}

/// Per-player state inside a match.
final class MatchPlayerState {
  /// Creates player match state.
  const MatchPlayerState({
    required this.playerId,
    required this.status,
    this.session,
    this.replay,
    this.latestFingerprint,
    this.finishOrderIndex,
  });

  /// Stable player id.
  final String playerId;

  /// Player lifecycle status.
  final PlayerStatus status;

  /// Player independent session state.
  final TriPeaksSessionState? session;

  /// Player attempt replay log.
  final ReplaySession? replay;

  /// Latest deterministic state fingerprint.
  final String? latestFingerprint;

  /// Optional deterministic finish order index.
  final int? finishOrderIndex;

  MatchPlayerState _copyWith({
    PlayerStatus? status,
    TriPeaksSessionState? session,
    ReplaySession? replay,
    String? latestFingerprint,
    bool clearLatestFingerprint = false,
    int? finishOrderIndex,
    bool clearFinishOrderIndex = false,
  }) {
    return MatchPlayerState(
      playerId: playerId,
      status: status ?? this.status,
      session: session ?? this.session,
      replay: replay ?? this.replay,
      latestFingerprint: clearLatestFingerprint
          ? null
          : (latestFingerprint ?? this.latestFingerprint),
      finishOrderIndex: clearFinishOrderIndex
          ? null
          : (finishOrderIndex ?? this.finishOrderIndex),
    );
  }

  /// Serializes player state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_player_state',
      'playerId': playerId,
      'status': status.name,
      if (session case final value?) 'session': value.toMap(),
      if (replay case final value?) 'replay': value.toMap(),
      if (latestFingerprint case final value?) 'latestFingerprint': value,
      if (finishOrderIndex case final value?) 'finishOrderIndex': value,
    };
  }

  /// Decodes player state from map without throwing.
  static DecodeResult<MatchPlayerState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_player_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final playerId = map['playerId'];
    final statusName = map['status'];
    final latestFingerprint = map['latestFingerprint'];
    final finishOrderIndex = map['finishOrderIndex'];
    if (playerId is! String ||
        statusName is! String ||
        (latestFingerprint != null && latestFingerprint is! String) ||
        (finishOrderIndex != null && finishOrderIndex is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match player primitive fields.',
        ),
      );
    }

    TriPeaksSessionState? session;
    final sessionMap = map['session'];
    if (sessionMap != null) {
      if (sessionMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'session must be a map when present.',
          ),
        );
      }
      final sessionResult = TriPeaksSessionState.tryFromMap(sessionMap);
      if (!sessionResult.isSuccess) {
        return DecodeResult.failure(sessionResult.error!);
      }
      session = sessionResult.value!;
    }

    ReplaySession? replay;
    final replayMap = map['replay'];
    if (replayMap != null) {
      if (replayMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'replay must be a map when present.',
          ),
        );
      }
      final replayResult = ReplaySession.tryFromMap(replayMap);
      if (!replayResult.isSuccess) {
        return DecodeResult.failure(replayResult.error!);
      }
      replay = replayResult.value!;
    }

    try {
      return DecodeResult.success(
        MatchPlayerState(
          playerId: playerId,
          status: PlayerStatus.values.byName(statusName),
          session: session,
          replay: replay,
          latestFingerprint: latestFingerprint as String?,
          finishOrderIndex: finishOrderIndex as int?,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match player payload: $error',
        ),
      );
    }
  }
}

/// Full multiplayer match state.
final class MatchState {
  /// Creates match state.
  const MatchState({
    required this.schemaVersion,
    required this.engineVersion,
    required this.config,
    required this.matchStatus,
    required this.authoritativeSequence,
    required this.players,
    this.finalResult,
  });

  /// Creates initial waiting match state.
  factory MatchState.newMatch({required MatchConfig config}) {
    return MatchState(
      schemaVersion: _serializationSchemaV1,
      engineVersion: config.engineVersion,
      config: config,
      matchStatus: MatchStatus.waiting,
      authoritativeSequence: 0,
      players: const <MatchPlayerState>[],
      finalResult: null,
    );
  }

  /// State schema version.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Match config.
  final MatchConfig config;

  /// Match lifecycle status.
  final MatchStatus matchStatus;

  /// Authoritative total ordering sequence.
  final int authoritativeSequence;

  /// Player states in deterministic join order.
  final List<MatchPlayerState> players;

  /// Immutable final match result once finalized.
  final FinalMatchResult? finalResult;

  MatchState _copyWith({
    MatchStatus? matchStatus,
    int? authoritativeSequence,
    List<MatchPlayerState>? players,
    FinalMatchResult? finalResult,
    bool clearFinalResult = false,
  }) {
    return MatchState(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      config: config,
      matchStatus: matchStatus ?? this.matchStatus,
      authoritativeSequence:
          authoritativeSequence ?? this.authoritativeSequence,
      players: List<MatchPlayerState>.unmodifiable(players ?? this.players),
      finalResult: clearFinalResult ? null : (finalResult ?? this.finalResult),
    );
  }

  /// Serializes match state to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'match_state',
      'engineVersion': engineVersion,
      'config': config.toMap(),
      'matchStatus': matchStatus.name,
      'authoritativeSequence': authoritativeSequence,
      'players':
          players.map((player) => player.toMap()).toList(growable: false),
      if (finalResult case final value?) 'finalResult': value.toMap(),
    };
  }

  /// Decodes match state from map without throwing.
  static DecodeResult<MatchState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'match_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final configMap = map['config'];
    if (configMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'config must be a map.',
        ),
      );
    }
    final configResult = MatchConfig.tryFromMap(configMap);
    if (!configResult.isSuccess) {
      return DecodeResult.failure(configResult.error!);
    }

    final statusName = map['matchStatus'];
    final engineVersion = map['engineVersion'];
    final seq = map['authoritativeSequence'];
    final playersRaw = map['players'];
    final finalResultRaw = map['finalResult'];
    if (statusName is! String ||
        engineVersion is! int ||
        seq is! int ||
        playersRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match state primitive fields.',
        ),
      );
    }

    final players = <MatchPlayerState>[];
    for (final raw in playersRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'players items must be maps.',
          ),
        );
      }
      final playerResult = MatchPlayerState.tryFromMap(raw);
      if (!playerResult.isSuccess) {
        return DecodeResult.failure(playerResult.error!);
      }
      players.add(playerResult.value!);
    }

    FinalMatchResult? finalResult;
    if (finalResultRaw != null) {
      if (finalResultRaw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'finalResult must be a map when present.',
          ),
        );
      }
      final finalResultDecode = FinalMatchResult.tryFromMap(finalResultRaw);
      if (!finalResultDecode.isSuccess) {
        return DecodeResult.failure(finalResultDecode.error!);
      }
      finalResult = finalResultDecode.value!;
    }

    try {
      return DecodeResult.success(
        MatchState(
          schemaVersion: _serializationSchemaV1,
          engineVersion: engineVersion,
          config: configResult.value!,
          matchStatus: MatchStatus.values.byName(statusName),
          authoritativeSequence: seq,
          players: List<MatchPlayerState>.unmodifiable(players),
          finalResult: finalResult,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid match state payload: $error',
        ),
      );
    }
  }
}

/// Base type for authoritative match events.
sealed class MatchEvent {
  const MatchEvent();

  /// Stable event discriminator.
  String get eventType;

  /// Serializes event to map.
  Map<String, dynamic> toMap();
}

/// Player joins a room.
final class JoinMatchEvent extends MatchEvent {
  /// Creates join event.
  const JoinMatchEvent({required this.playerId});

  /// Joining player id.
  final String playerId;

  @override
  String get eventType => 'join';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
    };
  }
}

/// Player leaves a room.
final class LeaveMatchEvent extends MatchEvent {
  /// Creates leave event.
  const LeaveMatchEvent({required this.playerId});

  /// Leaving player id.
  final String playerId;

  @override
  String get eventType => 'leave';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
    };
  }
}

/// Starts a waiting match.
final class StartMatchEvent extends MatchEvent {
  /// Creates start event.
  const StartMatchEvent();

  @override
  String get eventType => 'start';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
    };
  }
}

/// Submits one action attempt for one player.
final class SubmitMatchActionEvent extends MatchEvent {
  /// Creates submit action event.
  const SubmitMatchActionEvent({
    required this.playerId,
    required this.action,
    this.clientSeq,
  });

  /// Submitting player id.
  final String playerId;

  /// Submitted session action.
  final TriPeaksSessionAction action;

  /// Optional client-side sequence marker.
  final int? clientSeq;

  @override
  String get eventType => 'submit_action';

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'match_event',
      'eventType': eventType,
      'playerId': playerId,
      'action': sessionActionToMap(action),
      if (clientSeq case final value?) 'clientSeq': value,
    };
  }
}

/// Decodes one match event from map without throwing.
DecodeResult<MatchEvent> tryDecodeMatchEvent(Map<String, dynamic> map) {
  if (map['schemaVersion'] != _serializationSchemaV1) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unsupportedSchemaVersion,
        message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
      ),
    );
  }
  if (map['type'] != 'match_event') {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unknownType,
        message: 'Unknown type ${map['type']}.',
      ),
    );
  }

  final eventType = map['eventType'];
  if (eventType is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'eventType must be a string.',
      ),
    );
  }

  switch (eventType) {
    case 'join':
      final playerId = map['playerId'];
      if (playerId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'join requires string playerId.',
          ),
        );
      }
      return DecodeResult.success(JoinMatchEvent(playerId: playerId));

    case 'leave':
      final playerId = map['playerId'];
      if (playerId is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'leave requires string playerId.',
          ),
        );
      }
      return DecodeResult.success(LeaveMatchEvent(playerId: playerId));

    case 'start':
      return const DecodeResult.success(StartMatchEvent());

    case 'submit_action':
      final playerId = map['playerId'];
      final actionMap = map['action'];
      final clientSeq = map['clientSeq'];
      if (playerId is! String || actionMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'submit_action requires playerId and action map.',
          ),
        );
      }
      if (clientSeq != null && clientSeq is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'clientSeq must be int when present.',
          ),
        );
      }
      final decodedAction = tryDecodeSessionAction(actionMap);
      if (!decodedAction.isSuccess) {
        return DecodeResult.failure(decodedAction.error!);
      }
      return DecodeResult.success(
        SubmitMatchActionEvent(
          playerId: playerId,
          action: decodedAction.value!,
          clientSeq: clientSeq as int?,
        ),
      );

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown match event type "$eventType".',
        ),
      );
  }
}

/// Match reducer failure code.
enum MatchReduceFailureCode {
  matchFull,
  playerAlreadyJoined,
  playerNotFound,
  matchAlreadyStarted,
  matchNotStarted,
  matchAlreadyFinished,
  playerNotActive,
}

/// Typed match reducer failure.
final class MatchReduceFailure {
  /// Creates match reducer failure.
  const MatchReduceFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly code.
  final MatchReduceFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Result from match reducer.
final class MatchReduceResult {
  /// Creates match reducer result.
  const MatchReduceResult({
    required this.state,
    this.failure,
  });

  /// Resulting state.
  final MatchState state;

  /// Failure details for rejected event.
  final MatchReduceFailure? failure;

  /// Whether event was accepted.
  bool get isSuccess => failure == null;
}

/// Applies one [event] to [state] using pure deterministic reducer.
MatchReduceResult tryReduceMatch(MatchState state, MatchEvent event) {
  switch (event) {
    case JoinMatchEvent(playerId: final playerId):
      if (state.players.any((player) => player.playerId == playerId)) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerAlreadyJoined,
            message: 'Player already joined.',
          ),
        );
      }
      if (state.players.length >= state.config.maxPlayers) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchFull,
            message: 'Match is full.',
          ),
        );
      }
      if (state.matchStatus != MatchStatus.waiting) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyStarted,
            message: 'Match already started.',
          ),
        );
      }
      final nextPlayers = <MatchPlayerState>[
        ...state.players,
        MatchPlayerState(playerId: playerId, status: PlayerStatus.joined),
      ];
      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case LeaveMatchEvent(playerId: final playerId):
      final index = _playerIndex(state.players, playerId);
      if (index < 0) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerNotFound,
            message: 'Player not found.',
          ),
        );
      }
      final nextPlayers = state.players.toList(growable: false);
      final player = nextPlayers[index];
      nextPlayers[index] = player._copyWith(status: PlayerStatus.left);
      final maybeFinished = _deriveMatchStatusAfterPlayerUpdate(
        state.matchStatus,
        nextPlayers,
      );
      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          matchStatus: maybeFinished,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case StartMatchEvent():
      if (state.matchStatus == MatchStatus.finished) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyFinished,
            message: 'Match already finished.',
          ),
        );
      }
      if (state.matchStatus != MatchStatus.waiting) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyStarted,
            message: 'Match already started.',
          ),
        );
      }
      if (state.players.isEmpty) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchNotStarted,
            message: 'Cannot start without players.',
          ),
        );
      }

      final nextPlayers = <MatchPlayerState>[];
      for (final player in state.players) {
        if (player.status == PlayerStatus.left) {
          nextPlayers.add(player);
          continue;
        }
        final deal = newGameWithDealPolicy(
          state.config.matchSeed,
          scoreConfig: state.config.scoreConfig,
          roundRulesConfig: state.config.roundRulesConfig,
          undoConfig: state.config.undoConfig,
          streakConfig: state.config.streakConfig,
          strikeTimerConfig: state.config.strikeTimerConfig,
          bonusSlotsConfig: state.config.bonusSlotsConfig,
          dealPolicy: state.config.dealPolicyConfig,
        );
        if (!deal.isSuccess) {
          return MatchReduceResult(
            state: state,
            failure: const MatchReduceFailure(
              code: MatchReduceFailureCode.matchNotStarted,
              message: 'Unable to create deterministic match deal.',
            ),
          );
        }

        final round = deal.state!;
        final session = TriPeaksSessionState.newSession(
          ruleset: state.config.ruleset,
          seed: deal.attemptSeed,
          scoreConfig: state.config.scoreConfig,
          roundRulesConfig: state.config.roundRulesConfig,
          undoConfig: state.config.undoConfig,
          streakConfig: state.config.streakConfig,
          strikeTimerConfig: state.config.strikeTimerConfig,
          bonusSlotsConfig: state.config.bonusSlotsConfig,
        );
        final replay = ReplaySession.newSession(
          seed: session.seed ?? TriPeaksSessionState.defaultSeed,
          ruleset: session.ruleset,
          scoreConfig: session.scoreConfig,
          roundRulesConfig: session.roundRulesConfig,
          undoConfig: session.undoConfig,
          streakConfig: session.streakConfig,
          strikeTimerConfig: session.strikeTimerConfig,
          bonusSlotsConfig: session.bonusSlotsConfig,
        );
        final initialized = session._copyWith(currentRound: round);
        nextPlayers.add(
          player._copyWith(
            status: PlayerStatus.active,
            session: initialized,
            replay: replay,
            latestFingerprint: sessionFingerprint(initialized),
            clearFinishOrderIndex: true,
          ),
        );
      }

      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          matchStatus: MatchStatus.active,
          authoritativeSequence: state.authoritativeSequence + 1,
        ),
      );

    case SubmitMatchActionEvent(
        playerId: final playerId,
        action: final action,
        clientSeq: final clientSeq,
      ):
      if (state.matchStatus == MatchStatus.finished) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchAlreadyFinished,
            message: 'Match is already finished.',
          ),
        );
      }
      if (state.matchStatus != MatchStatus.active) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.matchNotStarted,
            message: 'Match is not active.',
          ),
        );
      }
      final index = _playerIndex(state.players, playerId);
      if (index < 0) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerNotFound,
            message: 'Player not found.',
          ),
        );
      }
      final player = state.players[index];
      if (player.status != PlayerStatus.active || player.session == null) {
        return MatchReduceResult(
          state: state,
          failure: const MatchReduceFailure(
            code: MatchReduceFailureCode.playerNotActive,
            message: 'Player is not active.',
          ),
        );
      }

      final nextSequence = state.authoritativeSequence + 1;
      final reduceResult = tryReduceTriPeaksSession(
        player.session!,
        action,
        tick: nextSequence,
      );

      final replay = recordAttempt(
        player.replay ??
            ReplaySession.newSession(
              seed: player.session!.seed ?? TriPeaksSessionState.defaultSeed,
              ruleset: player.session!.ruleset,
              scoreConfig: player.session!.scoreConfig,
              roundRulesConfig: player.session!.roundRulesConfig,
              undoConfig: player.session!.undoConfig,
              streakConfig: player.session!.streakConfig,
              strikeTimerConfig: player.session!.strikeTimerConfig,
              bonusSlotsConfig: player.session!.bonusSlotsConfig,
            ),
        action,
        reduceResult,
        tick: clientSeq ?? nextSequence,
      );

      var nextPlayer = player._copyWith(
        session: reduceResult.state,
        replay: replay,
      );
      if (!identical(reduceResult.state, player.session) ||
          reduceResult.isSuccess) {
        nextPlayer = nextPlayer._copyWith(
          latestFingerprint: sessionFingerprint(reduceResult.state),
        );
      }

      if (nextPlayer.status == PlayerStatus.active &&
          reduceResult.state.isSessionFinished) {
        final finishOrder =
            state.players.where((p) => p.finishOrderIndex != null).length + 1;
        nextPlayer = nextPlayer._copyWith(
          status: PlayerStatus.finished,
          finishOrderIndex: finishOrder,
          latestFingerprint: sessionFingerprint(reduceResult.state),
        );
      }

      final nextPlayers = state.players.toList(growable: false);
      nextPlayers[index] = nextPlayer;

      final maybeFinished = _deriveMatchStatusAfterPlayerUpdate(
        state.matchStatus,
        nextPlayers,
      );

      return MatchReduceResult(
        state: state._copyWith(
          players: nextPlayers,
          authoritativeSequence: nextSequence,
          matchStatus: maybeFinished,
        ),
      );
  }
}

int _playerIndex(List<MatchPlayerState> players, String playerId) {
  for (var i = 0; i < players.length; i++) {
    if (players[i].playerId == playerId) {
      return i;
    }
  }
  return -1;
}

MatchStatus _deriveMatchStatusAfterPlayerUpdate(
  MatchStatus current,
  List<MatchPlayerState> players,
) {
  if (current == MatchStatus.waiting) {
    return current;
  }
  final unfinishedActive = players.any(
    (player) => player.status == PlayerStatus.active,
  );
  if (!unfinishedActive) {
    return MatchStatus.finished;
  }
  return MatchStatus.active;
}

/// Deterministically applies ordered [events] from [initial] state.
MatchState replayMatchEvents(MatchState initial, List<MatchEvent> events) {
  var state = initial;
  for (final event in events) {
    final result = tryReduceMatch(state, event);
    state = result.state;
  }
  return state;
}
