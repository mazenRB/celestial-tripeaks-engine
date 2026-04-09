part of '../tripeaks_engine.dart';

/// Failure reason for rejected replay attempts.
enum ReplayFailureReason {
  gameAlreadyFinished,
  roundAlreadyFinished,
  roundNotFinished,
  alreadyOnLastRound,
  roundTimedOut,
  roundTimerDisabled,
  roundTimerNotStarted,
  roundTimerAlreadyStarted,
  staleRoundTimerUpdate,
  invalidRoundTimerElapsed,
  undoDisabled,
  nothingToUndo,
  strikeTimerDisabled,
  strikeTimerNotArmed,
  staleStrikeTimerExpiry,
  timeBonusTimerDisabled,
  timeBonusTimerNotArmed,
  staleTimeBonusExpiry,
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
