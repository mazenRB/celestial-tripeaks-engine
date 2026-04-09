part of '../tripeaks_engine.dart';

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

/// Action that explicitly starts a timed round.
final class StartRoundTimerAction extends TriPeaksAction {
  /// Creates a round-timer start action.
  const StartRoundTimerAction();

  /// Serializes action to JSON-friendly map.
  Map<String, dynamic> toMap() => roundActionToMap(this);
}

/// Action that advances a started round timer by [elapsedSeconds].
final class AdvanceRoundTimerAction extends TriPeaksAction {
  /// Creates a round-timer advancement action.
  const AdvanceRoundTimerAction({
    required this.elapsedSeconds,
    required this.deadlineToken,
  });

  /// Whole seconds elapsed since the previous timer update.
  final int elapsedSeconds;

  /// The deadline token expected by the sender.
  final int deadlineToken;

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
