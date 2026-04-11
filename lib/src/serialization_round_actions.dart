part of 'tripeaks_engine_internal.dart';

/// Serializes one round action with schema/type envelope.
Map<String, dynamic> roundActionToMap(TriPeaksAction action) {
  switch (action) {
    case StartRoundTimerAction():
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'start_round_timer',
      };
    case AdvanceRoundTimerAction(
        elapsedSeconds: final elapsedSeconds,
        deadlineToken: final deadlineToken,
      ):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'advance_round_timer',
        'elapsedSeconds': elapsedSeconds,
        'deadlineToken': deadlineToken,
      };
    case DrawFromStockAction(targetSlot: final targetSlot):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'draw_from_stock',
        if (targetSlot case final slot?) 'targetSlot': slot,
      };
    case RemoveTableauCardAction(index: final index, targetSlot: final slot):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'remove_tableau_card',
        'index': index,
        if (slot case final target?) 'targetSlot': target,
      };
    case UndoAction():
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'undo',
      };
    case UseBonusSlotAction(slotIndex: final slotIndex):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'use_bonus_slot',
        'slotIndex': slotIndex,
      };
    case StrikeTimerExpiredAction(deadlineToken: final deadlineToken):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'strike_timer_expired',
        'deadlineToken': deadlineToken,
      };
    case TimeBonusExpiredAction(deadlineToken: final deadlineToken):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_round_action',
        'actionType': 'time_bonus_expired',
        'deadlineToken': deadlineToken,
      };
  }
}

/// Decodes one round action envelope.
DecodeResult<TriPeaksAction> tryDecodeRoundAction(Map<String, dynamic> json) {
  final actionType = json['actionType'];
  if (actionType is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'Round action actionType must be a string.',
      ),
    );
  }

  switch (actionType) {
    case 'start_round_timer':
      return const DecodeResult.success(StartRoundTimerAction());
    case 'advance_round_timer':
      final elapsedSeconds = json['elapsedSeconds'];
      final deadlineToken = json['deadlineToken'];
      if (elapsedSeconds is! int || deadlineToken is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message:
                'advance_round_timer requires int elapsedSeconds and deadlineToken.',
          ),
        );
      }
      return DecodeResult.success(
        AdvanceRoundTimerAction(
          elapsedSeconds: elapsedSeconds,
          deadlineToken: deadlineToken,
        ),
      );
    case 'draw_from_stock':
      final targetSlot = json['targetSlot'];
      if (targetSlot != null && targetSlot is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'draw_from_stock targetSlot must be int when present.',
          ),
        );
      }
      return DecodeResult.success(
        DrawFromStockAction(targetSlot: targetSlot as int?),
      );
    case 'remove_tableau_card':
      final index = json['index'];
      if (index is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'remove_tableau_card requires int index.',
          ),
        );
      }
      final targetSlot = json['targetSlot'];
      if (targetSlot != null && targetSlot is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'remove_tableau_card targetSlot must be int when present.',
          ),
        );
      }
      return DecodeResult.success(
        RemoveTableauCardAction(index, targetSlot: targetSlot as int?),
      );
    case 'undo':
      return const DecodeResult.success(UndoAction());
    case 'use_bonus_slot':
      final slotIndex = json['slotIndex'];
      if (slotIndex is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'use_bonus_slot requires int slotIndex.',
          ),
        );
      }
      return DecodeResult.success(UseBonusSlotAction(slotIndex));
    case 'strike_timer_expired':
      final deadlineToken = json['deadlineToken'];
      if (deadlineToken is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'strike_timer_expired requires int deadlineToken.',
          ),
        );
      }
      return DecodeResult.success(
        StrikeTimerExpiredAction(deadlineToken: deadlineToken),
      );
    case 'time_bonus_expired':
      final deadlineToken = json['deadlineToken'];
      if (deadlineToken is! int) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'time_bonus_expired requires int deadlineToken.',
          ),
        );
      }
      return DecodeResult.success(
        TimeBonusExpiredAction(deadlineToken: deadlineToken),
      );
    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown round actionType "$actionType".',
        ),
      );
  }
}
