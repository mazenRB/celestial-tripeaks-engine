part of '../tripeaks_engine.dart';

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
  timeBonusTimerDisabled,
  timeBonusTimerNotArmed,
  staleTimeBonusExpiry,
}

/// Session action kinds for replay DTO.
enum ReplayActionKind {
  drawFromStock,
  removeTableauCard,
  undo,
  useBonusSlot,
  strikeTimerExpired,
  timeBonusExpired,
  startNextRound,
  abortRound,
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
          case TimeBonusExpiredAction(deadlineToken: final deadlineToken):
            return ReplayActionDto(
              kind: ReplayActionKind.timeBonusExpired,
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
      case ReplayActionKind.timeBonusExpired:
        final token = deadlineToken;
        if (token == null) {
          throw StateError('deadlineToken is required for timeBonusExpired.');
        }
        return PlayRoundAction(TimeBonusExpiredAction(deadlineToken: token));
      case ReplayActionKind.startNextRound:
        return const StartNextRoundAction();
      case ReplayActionKind.abortRound:
        return AbortRoundAction(reason: abortReason);
    }
  }
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
