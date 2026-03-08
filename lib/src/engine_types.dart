part of '../tripeaks_engine.dart';

/// Typed round-level reducer error codes.
enum TriPeaksErrorCode {
  invalidTableauIndex,
  tableauCardNotRemovable,
  emptyStock,
  undoDisabled,
  nothingToUndo,
  invalidBonusSlotIndex,
  bonusSlotClosed,
  strikeTimerDisabled,
  strikeTimerNotArmed,
  staleStrikeTimerExpiry,
  timeBonusTimerDisabled,
  timeBonusTimerNotArmed,
  staleTimeBonusExpiry,
}

/// Error codes for hint query failures.
enum HintErrorCode {
  hintDisabled,
  noHintAvailable,
}

/// Typed hint query error.
final class HintError {
  /// Creates a hint error.
  const HintError({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final HintErrorCode code;

  /// Human-friendly error message.
  final String message;
}

/// Result for hint query operations.
final class HintResult {
  /// Creates a hint result.
  const HintResult({
    this.moveIndex,
    this.error,
  });

  /// Suggested playable tableau index when successful.
  final int? moveIndex;

  /// Error details when hint is unavailable.
  final HintError? error;

  /// Whether the hint query succeeded.
  bool get isSuccess => error == null;
}

/// Error codes for invalid session-level actions.
enum TriPeaksSessionErrorCode {
  gameAlreadyFinished,
  roundAlreadyFinished,
  roundNotFinished,
  alreadyOnLastRound,
}

/// Reason for aborting a round.
enum AbortReason {
  userSkip,
  userQuit,
  timeout,
  disconnect,
}

/// Outcome type for a completed round.
enum RoundOutcome {
  won,
  lost,
  aborted,
}

/// Completed round metadata for session history.
final class RoundResult {
  /// Creates a completed round result.
  const RoundResult({
    required this.roundNumber,
    required this.outcome,
    this.abortReason,
    this.finalScore,
  });

  /// 1-based round number.
  final int roundNumber;

  /// Final round outcome.
  final RoundOutcome outcome;

  /// Abort reason for [RoundOutcome.aborted].
  final AbortReason? abortReason;

  /// Final round score captured at completion.
  ///
  /// This is nullable for backward decode compatibility with older payloads.
  final int? finalScore;

  /// Serializes result to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_result',
      'roundNumber': roundNumber,
      'outcome': outcome.name,
      if (abortReason case final reason?) 'abortReason': reason.name,
      if (finalScore case final value?) 'finalScore': value,
    };
  }

  /// Decodes result from map without throwing.
  static DecodeResult<RoundResult> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'round_result') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final roundNumber = map['roundNumber'];
    final outcomeName = map['outcome'];
    final reasonName = map['abortReason'];
    final finalScore = map['finalScore'];
    if (roundNumber is! int ||
        outcomeName is! String ||
        (reasonName != null && reasonName is! String) ||
        (finalScore != null && finalScore is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundResult payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        RoundResult(
          roundNumber: roundNumber,
          outcome: RoundOutcome.values.byName(outcomeName),
          abortReason:
              reasonName == null ? null : AbortReason.values.byName(reasonName),
          finalScore: finalScore as int?,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundResult payload: $error',
        ),
      );
    }
  }
}

/// A typed reducer error for invalid actions.
final class TriPeaksRuleError {
  /// Creates a rule error.
  const TriPeaksRuleError({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final TriPeaksErrorCode code;

  /// Human-friendly error message.
  final String message;
}

/// Result from a non-throwing reducer operation.
final class TriPeaksReduceResult {
  /// Creates a reducer result.
  const TriPeaksReduceResult({
    required this.state,
    required this.scoreDelta,
    required this.scoreBreakdown,
    required this.appliedMultiplier,
    this.error,
  });

  /// The resulting state.
  ///
  /// On failure, this is the original unchanged state.
  final TriPeaksState state;

  /// Score delta applied while processing the action.
  final int scoreDelta;

  /// Component-level explanation for the applied score delta.
  final ScoreDeltaBreakdown scoreBreakdown;

  /// Multiplier used on the accepted action's scoring computation.
  final int appliedMultiplier;

  /// Error details when reduction fails.
  final TriPeaksRuleError? error;

  /// Whether the action was applied successfully.
  bool get isSuccess => error == null;
}

/// A typed reducer error for invalid session-level actions.
final class TriPeaksSessionError {
  /// Creates a session error.
  const TriPeaksSessionError({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final TriPeaksSessionErrorCode code;

  /// Human-friendly error message.
  final String message;
}

/// Result from a non-throwing session reducer operation.
final class TriPeaksSessionReduceResult {
  /// Creates a session reducer result.
  const TriPeaksSessionReduceResult({
    required this.state,
    this.sessionError,
    this.roundError,
  });

  /// The resulting session state.
  ///
  /// On failure, this is the original unchanged state.
  final TriPeaksSessionState state;

  /// Session-level error details when reduction fails.
  final TriPeaksSessionError? sessionError;

  /// Round-level error details when an in-round action fails.
  final TriPeaksRuleError? roundError;

  /// Whether the action was applied successfully.
  bool get isSuccess => sessionError == null && roundError == null;
}

/// Rules that configure a TriPeaks session.
final class TriPeaksRuleset {
  /// Creates a ruleset with [roundsPerGame].
  ///
  /// Only `3`, `6`, and `10` are valid values.
  const TriPeaksRuleset({required this.roundsPerGame})
      : assert(
          roundsPerGame == 3 || roundsPerGame == 6 || roundsPerGame == 10,
          'roundsPerGame must be 3, 6, or 10.',
        );

  /// Preset ruleset with 3 rounds.
  static const TriPeaksRuleset threeRounds = TriPeaksRuleset(roundsPerGame: 3);

  /// Preset ruleset with 6 rounds.
  static const TriPeaksRuleset sixRounds = TriPeaksRuleset(roundsPerGame: 6);

  /// Preset ruleset with 10 rounds.
  static const TriPeaksRuleset tenRounds = TriPeaksRuleset(roundsPerGame: 10);

  /// Number of rounds in one full session.
  final int roundsPerGame;

  /// Serializes ruleset to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_ruleset',
      'roundsPerGame': roundsPerGame,
    };
  }

  /// Decodes ruleset from map without throwing.
  static DecodeResult<TriPeaksRuleset> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'tripeaks_ruleset') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final roundsPerGame = map['roundsPerGame'];
    if (roundsPerGame is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid TriPeaksRuleset payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
          TriPeaksRuleset(roundsPerGame: roundsPerGame));
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid TriPeaksRuleset payload: $error',
        ),
      );
    }
  }
}

/// Stable engine-owned gameplay preset identifiers.
enum TriPeaksModePreset {
  classic('classic'),
  celestial('celestial');

  const TriPeaksModePreset(this.modeId);

  /// Stable serialized id for this preset.
  final String modeId;

  /// Parses a preset id without throwing.
  static TriPeaksModePreset? tryParseModeId(String value) {
    for (final preset in values) {
      if (preset.modeId == value) {
        return preset;
      }
    }
    return null;
  }
}

/// Base type for all TriPeaks actions.
sealed class TriPeaksAction {
  const TriPeaksAction();
}

/// Action that draws one card from stock to waste.
final class DrawFromStockAction extends TriPeaksAction {
  /// Creates a stock draw action.
  const DrawFromStockAction({this.targetSlot});

  /// Optional bonus-slot target (1-based). If omitted, slot priority applies.
  final int? targetSlot;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that removes one exposed tableau card to waste.
final class RemoveTableauCardAction extends TriPeaksAction {
  /// Creates a card-removal action at [index].
  const RemoveTableauCardAction(this.index, {this.targetSlot});

  /// The tableau index to remove.
  final int index;

  /// Optional bonus-slot target (1-based). If omitted, slot priority applies.
  final int? targetSlot;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that undoes one previously successful action.
final class UndoAction extends TriPeaksAction {
  /// Creates an undo action.
  const UndoAction();

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that explicitly uses one bonus slot by index (1-based).
final class UseBonusSlotAction extends TriPeaksAction {
  /// Creates a bonus-slot usage action.
  const UseBonusSlotAction(this.slotIndex);

  /// Target slot index in range `1..3`.
  final int slotIndex;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that requests strike-expiry processing for [deadlineToken].
final class StrikeTimerExpiredAction extends TriPeaksAction {
  /// Creates a strike-expiry action.
  const StrikeTimerExpiredAction({required this.deadlineToken});

  /// The deadline token expected by the sender.
  final int deadlineToken;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that requests time-bonus expiry processing for [deadlineToken].
final class TimeBonusExpiredAction extends TriPeaksAction {
  /// Creates a time-bonus expiry action.
  const TimeBonusExpiredAction({required this.deadlineToken});

  /// The deadline token expected by the sender.
  final int deadlineToken;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Base type for all session-level actions.
sealed class TriPeaksSessionAction {
  const TriPeaksSessionAction();
}

/// Action that applies a single in-round action.
final class PlayRoundAction extends TriPeaksSessionAction {
  /// Creates a play action for one [action] in the current round.
  const PlayRoundAction(this.action);

  /// The in-round action to apply.
  final TriPeaksAction action;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => sessionActionToMap(this);
}

/// Action that starts the next round.
final class StartNextRoundAction extends TriPeaksSessionAction {
  /// Creates a next-round action.
  const StartNextRoundAction();

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => sessionActionToMap(this);
}

/// Action that aborts the active round.
final class AbortRoundAction extends TriPeaksSessionAction {
  /// Creates an abort action.
  ///
  /// If [reason] is omitted, [AbortReason.userSkip] is used.
  const AbortRoundAction({this.reason});

  /// Optional reason for aborting.
  final AbortReason? reason;

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => sessionActionToMap(this);
}

/// Immutable TriPeaks game state.
