part of '../tripeaks_engine.dart';

/// Session replay payload for deterministic reconstruction.
final class ReplaySession {
  /// Supported replay schema version.
  static const int supportedSchemaVersion = 1;

  /// Creates a replay payload.
  const ReplaySession({
    required this.schemaVersion,
    required this.engineVersion,
    required this.seed,
    required this.ruleset,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.entries,
  });

  /// Creates an empty replay log for a deterministic session.
  factory ReplaySession.newSession({
    required int seed,
    TriPeaksRuleset ruleset = TriPeaksRuleset.threeRounds,
    ScoreConfig scoreConfig = const ScoreConfig(),
    RoundRulesConfig roundRulesConfig = const RoundRulesConfig(),
    UndoConfig undoConfig = const UndoConfig(),
    StreakConfig streakConfig = const StreakConfig(),
    StrikeTimerConfig strikeTimerConfig = const StrikeTimerConfig(),
    BonusSlotsConfig bonusSlotsConfig = const BonusSlotsConfig(),
    int schemaVersion = supportedSchemaVersion,
    int engineVersion = 1,
  }) {
    return ReplaySession(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      seed: seed,
      ruleset: ruleset,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      entries: const <ReplayEntry>[],
    );
  }

  /// Replay schema version.
  final int schemaVersion;

  /// Engine version used to produce this replay.
  final int engineVersion;

  /// Initial deterministic seed.
  final int seed;

  /// Session ruleset.
  final TriPeaksRuleset ruleset;

  /// Score config.
  final ScoreConfig scoreConfig;

  /// Round rules config.
  final RoundRulesConfig roundRulesConfig;

  /// Undo config.
  final UndoConfig undoConfig;

  /// Streak config.
  final StreakConfig streakConfig;

  /// Strike timer config.
  final StrikeTimerConfig strikeTimerConfig;

  /// Bonus-slots config.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Ordered append-only attempts log.
  final List<ReplayEntry> entries;

  /// Serializes replay to a JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'replay_session',
      'engineVersion': engineVersion,
      'seed': seed,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'entries': entries.map((entry) => entry.toMap()).toList(growable: false),
    };
  }

  /// Parses replay from [map] without throwing.
  static DecodeResult<ReplaySession> tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'schemaVersion must be an int.',
        ),
      );
    }
    if (schemaVersion != supportedSchemaVersion) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion $schemaVersion.',
        ),
      );
    }
    if (map['type'] != 'replay_session') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final rulesetMap = map['ruleset'];
    if (rulesetMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'ruleset must be a map.',
        ),
      );
    }
    final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!rulesetResult.isSuccess) {
      return DecodeResult.failure(rulesetResult.error!);
    }
    final scoreConfigMap = map['scoreConfig'];
    if (scoreConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'scoreConfig must be a map.',
        ),
      );
    }
    final scoreConfigResult = ScoreConfig.tryFromMap(scoreConfigMap);
    if (!scoreConfigResult.isSuccess) {
      return DecodeResult.failure(scoreConfigResult.error!);
    }
    final roundRulesMap = map['roundRulesConfig'];
    if (roundRulesMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundRulesConfig must be a map.',
        ),
      );
    }
    final roundRulesResult = RoundRulesConfig.tryFromMap(roundRulesMap);
    if (!roundRulesResult.isSuccess) {
      return DecodeResult.failure(roundRulesResult.error!);
    }
    final undoConfigMap = map['undoConfig'];
    if (undoConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'undoConfig must be a map.',
        ),
      );
    }
    final undoConfigResult = UndoConfig.tryFromMap(undoConfigMap);
    if (!undoConfigResult.isSuccess) {
      return DecodeResult.failure(undoConfigResult.error!);
    }
    final streakConfigMap = map['streakConfig'];
    if (streakConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'streakConfig must be a map.',
        ),
      );
    }
    final streakConfigResult = StreakConfig.tryFromMap(streakConfigMap);
    if (!streakConfigResult.isSuccess) {
      return DecodeResult.failure(streakConfigResult.error!);
    }
    final strikeTimerConfigMap = map['strikeTimerConfig'];
    if (strikeTimerConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'strikeTimerConfig must be a map.',
        ),
      );
    }
    final strikeTimerConfigResult = StrikeTimerConfig.tryFromMap(
      strikeTimerConfigMap,
    );
    if (!strikeTimerConfigResult.isSuccess) {
      return DecodeResult.failure(strikeTimerConfigResult.error!);
    }
    final bonusSlotsConfigMap = map['bonusSlotsConfig'];
    if (bonusSlotsConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'bonusSlotsConfig must be a map.',
        ),
      );
    }
    final bonusSlotsConfigResult =
        BonusSlotsConfig.tryFromMap(bonusSlotsConfigMap);
    if (!bonusSlotsConfigResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfigResult.error!);
    }

    final entriesRaw = map['entries'];
    if (entriesRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'entries must be a list.',
        ),
      );
    }
    final entries = <ReplayEntry>[];
    for (final raw in entriesRaw) {
      if (raw is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'entries must contain map items.',
          ),
        );
      }
      final entryResult = ReplayEntry.tryFromMap(raw);
      if (!entryResult.isSuccess) {
        return DecodeResult.failure(entryResult.error!);
      }
      entries.add(entryResult.value!);
    }

    final engineVersion = map['engineVersion'];
    final seed = map['seed'];
    if (engineVersion is! int || seed is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'engineVersion and seed must be ints.',
        ),
      );
    }

    return DecodeResult.success(
      ReplaySession(
        schemaVersion: schemaVersion,
        engineVersion: engineVersion,
        seed: seed,
        ruleset: rulesetResult.value!,
        scoreConfig: scoreConfigResult.value!,
        roundRulesConfig: roundRulesResult.value!,
        undoConfig: undoConfigResult.value!,
        streakConfig: streakConfigResult.value!,
        strikeTimerConfig: strikeTimerConfigResult.value!,
        bonusSlotsConfig: bonusSlotsConfigResult.value!,
        entries: List<ReplayEntry>.unmodifiable(entries),
      ),
    );
  }

  ReplaySession _copyWith({
    List<ReplayEntry>? entries,
  }) {
    return ReplaySession(
      schemaVersion: schemaVersion,
      engineVersion: engineVersion,
      seed: seed,
      ruleset: ruleset,
      scoreConfig: scoreConfig,
      roundRulesConfig: roundRulesConfig,
      undoConfig: undoConfig,
      streakConfig: streakConfig,
      strikeTimerConfig: strikeTimerConfig,
      bonusSlotsConfig: bonusSlotsConfig,
      entries: List<ReplayEntry>.unmodifiable(entries ?? this.entries),
    );
  }
}

/// Backwards-compatible alias.
typedef TriPeaksReplay = ReplaySession;

/// Failure reason for rejected replay attempts.
enum ReplayFailureReason {
  gameAlreadyFinished,
  roundAlreadyFinished,
  roundNotFinished,
  alreadyOnLastRound,
  undoDisabled,
  nothingToUndo,
  strikeTimerDisabled,
  strikeTimerNotArmed,
  staleStrikeTimerExpiry,
}

/// Session action descriptor for replay serialization.
final class ReplayActionDto {
  /// Creates a replay action descriptor.
  const ReplayActionDto({
    required this.kind,
    this.tableauIndex,
    this.targetSlot,
    this.slotIndex,
    this.deadlineToken,
    this.abortReason,
  });

  /// Creates DTO from runtime action.
  factory ReplayActionDto.fromSessionAction(TriPeaksSessionAction action) {
    switch (action) {
      case PlayRoundAction(action: final roundAction):
        switch (roundAction) {
          case DrawFromStockAction(targetSlot: final targetSlot):
            return ReplayActionDto(
              kind: ReplayActionKind.drawFromStock,
              targetSlot: targetSlot,
            );
          case RemoveTableauCardAction(
              index: final index,
              targetSlot: final targetSlot,
            ):
            return ReplayActionDto(
              kind: ReplayActionKind.removeTableauCard,
              tableauIndex: index,
              targetSlot: targetSlot,
            );
          case UndoAction():
            return const ReplayActionDto(kind: ReplayActionKind.undo);
          case UseBonusSlotAction(slotIndex: final slotIndex):
            return ReplayActionDto(
              kind: ReplayActionKind.useBonusSlot,
              slotIndex: slotIndex,
            );
          case StrikeTimerExpiredAction(deadlineToken: final deadlineToken):
            return ReplayActionDto(
              kind: ReplayActionKind.strikeTimerExpired,
              deadlineToken: deadlineToken,
            );
        }
      case StartNextRoundAction():
        return const ReplayActionDto(kind: ReplayActionKind.startNextRound);
      case AbortRoundAction(reason: final reason):
        return ReplayActionDto(
          kind: ReplayActionKind.abortRound,
          abortReason: reason,
        );
    }
  }

  /// Parses DTO from [map] without throwing.
  static DecodeResult<ReplayActionDto> tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'schemaVersion must be an int.',
        ),
      );
    }
    if (schemaVersion != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion $schemaVersion.',
        ),
      );
    }
    if (map['type'] != 'replay_action') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final kindName = map['kind'];
    final reasonName = map['abortReason'];
    if (kindName is! String || (reasonName != null && reasonName is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid replay action payload.',
        ),
      );
    }

    try {
      return DecodeResult.success(
        ReplayActionDto(
          kind: ReplayActionKind.values.byName(kindName),
          tableauIndex: map['tableauIndex'] as int?,
          targetSlot: map['targetSlot'] as int?,
          slotIndex: map['slotIndex'] as int?,
          deadlineToken: map['deadlineToken'] as int?,
          abortReason:
              reasonName == null ? null : AbortReason.values.byName(reasonName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid replay action payload: $error',
        ),
      );
    }
  }

  /// Action kind.
  final ReplayActionKind kind;

  /// Tableau index for remove action.
  final int? tableauIndex;

  /// Slot index for bonus-slot action.
  final int? slotIndex;

  /// Optional target slot for draw/remove actions.
  final int? targetSlot;

  /// Token for strike-expiry action.
  final int? deadlineToken;

  /// Optional abort reason.
  final AbortReason? abortReason;

  /// Serializes to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'replay_action',
      'kind': kind.name,
      if (tableauIndex case final index?) 'tableauIndex': index,
      if (targetSlot case final target?) 'targetSlot': target,
      if (slotIndex case final slot?) 'slotIndex': slot,
      if (deadlineToken case final token?) 'deadlineToken': token,
      if (abortReason case final reason?) 'abortReason': reason.name,
    };
  }

  /// Converts back to runtime session action.
  TriPeaksSessionAction toSessionAction() {
    switch (kind) {
      case ReplayActionKind.drawFromStock:
        return PlayRoundAction(
          DrawFromStockAction(targetSlot: targetSlot),
        );
      case ReplayActionKind.removeTableauCard:
        final index = tableauIndex;
        if (index == null) {
          throw StateError('tableauIndex is required for removeTableauCard.');
        }
        return PlayRoundAction(
          RemoveTableauCardAction(index, targetSlot: targetSlot),
        );
      case ReplayActionKind.undo:
        return const PlayRoundAction(UndoAction());
      case ReplayActionKind.useBonusSlot:
        final index = slotIndex;
        if (index == null) {
          throw StateError('slotIndex is required for useBonusSlot.');
        }
        return PlayRoundAction(UseBonusSlotAction(index));
      case ReplayActionKind.strikeTimerExpired:
        final token = deadlineToken;
        if (token == null) {
          throw StateError('deadlineToken is required for strikeTimerExpired.');
        }
        return PlayRoundAction(StrikeTimerExpiredAction(deadlineToken: token));
      case ReplayActionKind.startNextRound:
        return const StartNextRoundAction();
      case ReplayActionKind.abortRound:
        return AbortRoundAction(reason: abortReason);
    }
  }
}

/// Session action kinds for replay DTO.
enum ReplayActionKind {
  drawFromStock,
  removeTableauCard,
  undo,
  useBonusSlot,
  strikeTimerExpired,
  startNextRound,
  abortRound,
}

/// Append-only replay entry for one attempted action.
final class ReplayEntry {
  /// Creates replay entry.
  const ReplayEntry({
    required this.sequence,
    required this.action,
    required this.accepted,
    required this.tick,
    this.failureReason,
  });

  /// Parses entry from [map] without throwing.
  static DecodeResult<ReplayEntry> tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'schemaVersion must be an int.',
        ),
      );
    }
    if (schemaVersion != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion $schemaVersion.',
        ),
      );
    }
    if (map['type'] != 'replay_entry') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final actionMap = map['action'];
    if (actionMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Replay entry action must be a map.',
        ),
      );
    }
    final actionResult = ReplayActionDto.tryFromMap(actionMap);
    if (!actionResult.isSuccess) {
      return DecodeResult.failure(actionResult.error!);
    }

    final sequence = map['sequence'];
    final accepted = map['accepted'];
    final tick = map['tick'];
    final failureName = map['failureReason'];
    if (sequence is! int ||
        accepted is! bool ||
        tick is! int ||
        (failureName != null && failureName is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid replay entry payload.',
        ),
      );
    }

    try {
      return DecodeResult.success(
        ReplayEntry(
          sequence: sequence,
          action: actionResult.value!,
          accepted: accepted,
          tick: tick,
          failureReason: failureName == null
              ? null
              : ReplayFailureReason.values.byName(failureName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid replay entry payload: $error',
        ),
      );
    }
  }

  /// Ordered sequence number.
  final int sequence;

  /// Serialized action descriptor.
  final ReplayActionDto action;

  /// Whether this attempt should be applied during replay.
  final bool accepted;

  /// Logical progression marker.
  final int tick;

  /// Failure reason when [accepted] is false.
  final ReplayFailureReason? failureReason;

  /// Serializes entry to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'replay_entry',
      'sequence': sequence,
      'action': action.toMap(),
      'accepted': accepted,
      'tick': tick,
      if (failureReason case final reason?) 'failureReason': reason.name,
    };
  }
}

/// Result of reducing state and appending one replay entry.
final class ReplayRecordResult {
  /// Creates replay recording result.
  const ReplayRecordResult({
    required this.replay,
    required this.state,
    required this.reduceResult,
  });

  /// Updated replay payload.
  final ReplaySession replay;

  /// Resulting session state.
  final TriPeaksSessionState state;

  /// Reducer result used to build entry metadata.
  final TriPeaksSessionReduceResult reduceResult;
}

/// Appends a replay entry from one attempted [action] and [result].
ReplaySession recordAttempt(
  ReplaySession replay,
  TriPeaksSessionAction action,
  TriPeaksSessionReduceResult result, {
  int? tick,
}) {
  final sequence = replay.entries.length + 1;
  final entryTick = tick ?? sequence;
  final accepted = _isAcceptedResult(result);
  final entry = ReplayEntry(
    sequence: sequence,
    action: ReplayActionDto.fromSessionAction(action),
    accepted: accepted,
    tick: entryTick,
    failureReason: accepted ? null : _mapFailureReason(result),
  );
  return replay._copyWith(entries: <ReplayEntry>[...replay.entries, entry]);
}

/// Applies one attempted [action], then records that attempt into [replay].
ReplayRecordResult recordAction(
  ReplaySession replay,
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  final reduceResult = tryReduceTriPeaksSession(state, action, tick: tick);
  final nextReplay = recordAttempt(
    replay,
    action,
    reduceResult,
    tick: tick,
  );
  return ReplayRecordResult(
    replay: nextReplay,
    state: reduceResult.state,
    reduceResult: reduceResult,
  );
}

/// Rebuilds final session state by replaying accepted entries only.
TriPeaksSessionState replayToState(ReplaySession replay) {
  return replayStep(replay, replay.entries.length);
}

/// Rebuilds state after first [count] replay entries.
///
/// Only entries with `accepted=true` are applied.
TriPeaksSessionState replayStep(ReplaySession replay, int count) {
  if (count < 0 || count > replay.entries.length) {
    throw RangeError.range(count, 0, replay.entries.length, 'count');
  }

  var state = TriPeaksSessionState.newSession(
    ruleset: replay.ruleset,
    seed: replay.seed,
    scoreConfig: replay.scoreConfig,
    roundRulesConfig: replay.roundRulesConfig,
    undoConfig: replay.undoConfig,
    streakConfig: replay.streakConfig,
    strikeTimerConfig: replay.strikeTimerConfig,
    bonusSlotsConfig: replay.bonusSlotsConfig,
  );

  final ordered = replay.entries.take(count).toList(growable: false)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));

  for (final entry in ordered) {
    if (!entry.accepted) {
      continue;
    }
    final result = tryReduceTriPeaksSession(
      state,
      entry.action.toSessionAction(),
      tick: entry.tick,
    );
    state = result.state;
  }

  return state;
}

bool _isAcceptedResult(TriPeaksSessionReduceResult result) {
  if (result.isSuccess) {
    return true;
  }
  if (result.roundError case TriPeaksRuleError(code: final code)) {
    switch (code) {
      case TriPeaksErrorCode.invalidTableauIndex:
      case TriPeaksErrorCode.tableauCardNotRemovable:
      case TriPeaksErrorCode.emptyStock:
        return true;
      case TriPeaksErrorCode.undoDisabled:
      case TriPeaksErrorCode.nothingToUndo:
      case TriPeaksErrorCode.invalidBonusSlotIndex:
      case TriPeaksErrorCode.bonusSlotClosed:
      case TriPeaksErrorCode.strikeTimerDisabled:
      case TriPeaksErrorCode.strikeTimerNotArmed:
      case TriPeaksErrorCode.staleStrikeTimerExpiry:
        return false;
    }
  }
  return false;
}

ReplayFailureReason _mapFailureReason(TriPeaksSessionReduceResult result) {
  if (result.sessionError case TriPeaksSessionError(code: final code)) {
    switch (code) {
      case TriPeaksSessionErrorCode.gameAlreadyFinished:
        return ReplayFailureReason.gameAlreadyFinished;
      case TriPeaksSessionErrorCode.roundAlreadyFinished:
        return ReplayFailureReason.roundAlreadyFinished;
      case TriPeaksSessionErrorCode.roundNotFinished:
        return ReplayFailureReason.roundNotFinished;
      case TriPeaksSessionErrorCode.alreadyOnLastRound:
        return ReplayFailureReason.alreadyOnLastRound;
    }
  }
  if (result.roundError case TriPeaksRuleError(code: final code)) {
    switch (code) {
      case TriPeaksErrorCode.undoDisabled:
        return ReplayFailureReason.undoDisabled;
      case TriPeaksErrorCode.nothingToUndo:
        return ReplayFailureReason.nothingToUndo;
      case TriPeaksErrorCode.strikeTimerDisabled:
        return ReplayFailureReason.strikeTimerDisabled;
      case TriPeaksErrorCode.strikeTimerNotArmed:
        return ReplayFailureReason.strikeTimerNotArmed;
      case TriPeaksErrorCode.staleStrikeTimerExpiry:
        return ReplayFailureReason.staleStrikeTimerExpiry;
      case TriPeaksErrorCode.invalidTableauIndex:
      case TriPeaksErrorCode.tableauCardNotRemovable:
      case TriPeaksErrorCode.emptyStock:
      case TriPeaksErrorCode.invalidBonusSlotIndex:
      case TriPeaksErrorCode.bonusSlotClosed:
        break;
    }
  }
  return ReplayFailureReason.roundAlreadyFinished;
}
