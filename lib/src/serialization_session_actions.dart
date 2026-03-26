part of '../tripeaks_engine.dart';

/// Serializes one session action with schema/type envelope.
Map<String, dynamic> sessionActionToMap(TriPeaksSessionAction action) {
  switch (action) {
    case PlayRoundAction(action: final roundAction):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_session_action',
        'actionType': 'play_round',
        'roundAction': roundActionToMap(roundAction),
      };
    case StartNextRoundAction():
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_session_action',
        'actionType': 'start_next_round',
      };
    case AbortRoundAction(reason: final reason):
      return <String, dynamic>{
        'schemaVersion': _serializationSchemaV1,
        'type': 'tripeaks_session_action',
        'actionType': 'abort_round',
        'reason': (reason ?? AbortReason.userSkip).name,
      };
  }
}

/// Decodes one session action envelope.
DecodeResult<TriPeaksSessionAction> tryDecodeSessionAction(
  Map<String, dynamic> json,
) {
  final actionType = json['actionType'];
  if (actionType is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'Session action actionType must be a string.',
      ),
    );
  }

  switch (actionType) {
    case 'play_round':
      final roundActionMap = json['roundAction'];
      if (roundActionMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'play_round requires roundAction map.',
          ),
        );
      }
      final decodedRound = tryDecodeRoundAction(roundActionMap);
      if (!decodedRound.isSuccess) {
        return DecodeResult.failure(decodedRound.error!);
      }
      return DecodeResult.success(PlayRoundAction(decodedRound.value!));

    case 'start_next_round':
      return const DecodeResult.success(StartNextRoundAction());

    case 'abort_round':
      final reasonName = json['reason'];
      if (reasonName != null && reasonName is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'abort_round reason must be a string when present.',
          ),
        );
      }
      try {
        final reason = reasonName == null
            ? AbortReason.userSkip
            : AbortReason.values.byName(reasonName);
        return DecodeResult.success(AbortRoundAction(reason: reason));
      } on Object catch (error) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Invalid abort reason: $error',
          ),
        );
      }

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown session actionType "$actionType".',
        ),
      );
  }
}
