part of '../tripeaks_engine.dart';

TriPeaksRuleError? _validateAction(TriPeaksState state, TriPeaksAction action) {
  if (state.isTimedOut) {
    return const TriPeaksRuleError(
      code: TriPeaksErrorCode.roundTimedOut,
      message: 'Round has already timed out.',
    );
  }
  if (state.isRoundTimerAwaitingStart && action is! StartRoundTimerAction) {
    return const TriPeaksRuleError(
      code: TriPeaksErrorCode.roundTimerNotStarted,
      message: 'Round timer has not started yet.',
    );
  }
  switch (action) {
    case StartRoundTimerAction():
      if (!state.hasActiveRoundTimer) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.roundTimerDisabled,
          message: 'Round timer is disabled for this round.',
        );
      }
      if (state.roundTimerState.isStarted) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.roundTimerAlreadyStarted,
          message: 'Round timer is already started.',
        );
      }
      return null;

    case AdvanceRoundTimerAction(
        elapsedSeconds: final elapsedSeconds,
        deadlineToken: final deadlineToken,
      ):
      if (!state.hasActiveRoundTimer) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.roundTimerDisabled,
          message: 'Round timer is disabled for this round.',
        );
      }
      if (!state.roundTimerState.isStarted) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.roundTimerNotStarted,
          message: 'Round timer has not started yet.',
        );
      }
      if (elapsedSeconds <= 0) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.invalidRoundTimerElapsed,
          message: 'Round timer elapsedSeconds must be positive.',
        );
      }
      if (deadlineToken != state.roundTimerState.deadlineToken) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.staleRoundTimerUpdate,
          message: 'Stale round timer token $deadlineToken (expected '
              '${state.roundTimerState.deadlineToken}).',
        );
      }
      return null;

    case DrawFromStockAction(targetSlot: final targetSlot):
      if (!state.canDrawFromStock) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.emptyStock,
          message: 'Stock is empty.',
        );
      }
      if (targetSlot case final slot?) {
        if (slot != 1) {
          return const TriPeaksRuleError(
            code: TriPeaksErrorCode.invalidBonusSlotIndex,
            message: 'Draw actions can only target slot 1.',
          );
        }
        if (!state.isBonusSlotIndexInRange(slot)) {
          return TriPeaksRuleError(
            code: TriPeaksErrorCode.invalidBonusSlotIndex,
            message:
                'Bonus slot index $slot is out of range 1..${state.bonusSlotsConfig.maxSlots}.',
          );
        }
        if (!state.isBonusSlotOpen(slot)) {
          return TriPeaksRuleError(
            code: TriPeaksErrorCode.bonusSlotClosed,
            message: 'Bonus slot $slot is closed.',
          );
        }
      }
      return null;

    case RemoveTableauCardAction(index: final index, targetSlot: final slot):
      if (index < 0 || index >= state.tableau.length) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.invalidTableauIndex,
          message: 'Tableau index $index is out of range.',
        );
      }
      if (slot != null && !state.isBonusSlotIndexInRange(slot)) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.invalidBonusSlotIndex,
          message:
              'Bonus slot index $slot is out of range 1..${state.bonusSlotsConfig.maxSlots}.',
        );
      }
      if (slot != null && !state.isBonusSlotOpen(slot)) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.bonusSlotClosed,
          message: 'Bonus slot $slot is closed.',
        );
      }
      if (!state.canRemoveTableau(index, targetSlot: slot)) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.tableauCardNotRemovable,
          message: 'Tableau index $index is not removable.',
        );
      }
      return null;

    case UndoAction():
      if (!state.undoConfig.enabled) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.undoDisabled,
          message: 'Undo is disabled for this round.',
        );
      }
      if (state._undoHistory.isEmpty) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.nothingToUndo,
          message: 'There are no actions to undo.',
        );
      }
      return null;

    case UseBonusSlotAction(slotIndex: final slotIndex):
      if (slotIndex < 1 || slotIndex > state.bonusSlotsConfig.maxSlots) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.invalidBonusSlotIndex,
          message:
              'Bonus slot index $slotIndex is out of range 1..${state.bonusSlotsConfig.maxSlots}.',
        );
      }
      if (!state.canUseBonusSlot(slotIndex)) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.bonusSlotClosed,
          message: 'Bonus slot $slotIndex is closed.',
        );
      }
      return null;

    case StrikeTimerExpiredAction(deadlineToken: final deadlineToken):
      if (state.scoreConfig.multiplierMode == ScoreMultiplierMode.timeBonus) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.strikeTimerDisabled,
          message: 'Strike timer is disabled for this round.',
        );
      }
      if (!state.strikeTimerConfig.enabled) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.strikeTimerDisabled,
          message: 'Strike timer is disabled for this round.',
        );
      }
      if (!state.strikeTimerState.isArmed) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.strikeTimerNotArmed,
          message: 'Strike timer is not armed.',
        );
      }
      if (deadlineToken != state.strikeTimerState.deadlineToken) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.staleStrikeTimerExpiry,
          message: 'Stale strike timer expiry token $deadlineToken (expected '
              '${state.strikeTimerState.deadlineToken}).',
        );
      }
      return null;

    case TimeBonusExpiredAction(deadlineToken: final deadlineToken):
      if (state.scoreConfig.multiplierMode != ScoreMultiplierMode.timeBonus) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.timeBonusTimerDisabled,
          message: 'Time bonus timer is disabled.',
        );
      }
      if (state.timeBonusTimerState.remainingSeconds == 0) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.timeBonusTimerNotArmed,
          message: 'Time bonus timer is not armed.',
        );
      }
      if (deadlineToken != state.timeBonusTimerState.deadlineToken) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.staleTimeBonusExpiry,
          message: 'Stale time bonus expiry token $deadlineToken (expected '
              '${state.timeBonusTimerState.deadlineToken}).',
        );
      }
      return null;
  }
}
