part of '../tripeaks_engine.dart';

const int _saveSchemaVersionV1 = 1;

/// Typed save decode failure codes.
enum SaveDecodeFailureCode {
  unsupportedVersion,
  invalidPayload,
  unknownType,
  corruptSave,
}

/// Typed save decode failure.
final class SaveDecodeFailure {
  /// Creates save decode failure.
  const SaveDecodeFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final SaveDecodeFailureCode code;

  /// Human-friendly error message.
  final String message;
}

/// Typed save decode result.
final class SaveDecodeResult<T> {
  /// Creates successful decode result.
  const SaveDecodeResult.success(this.value)
      : error = null,
        isSuccess = true;

  /// Creates failed decode result.
  const SaveDecodeResult.failure(this.error)
      : value = null,
        isSuccess = false;

  /// Decoded value when successful.
  final T? value;

  /// Failure details when decode fails.
  final SaveDecodeFailure? error;

  /// Whether decode succeeded.
  final bool isSuccess;
}

/// Decoded round save payload.
final class DecodedRoundSave {
  /// Creates decoded round save.
  const DecodedRoundSave({
    required this.state,
    required this.engineVersion,
    required this.savedAtSequence,
    required this.fingerprint,
  });

  /// Decoded round state.
  final TriPeaksState state;

  /// Engine version from envelope.
  final int engineVersion;

  /// Logical save sequence marker.
  final int savedAtSequence;

  /// Stored/verified fingerprint.
  final String fingerprint;
}

/// Decoded session save payload.
final class DecodedSessionSave {
  /// Creates decoded session save.
  const DecodedSessionSave({
    required this.state,
    required this.engineVersion,
    required this.savedAtSequence,
    required this.fingerprint,
  });

  /// Decoded session state.
  final TriPeaksSessionState state;

  /// Engine version from envelope.
  final int engineVersion;

  /// Logical save sequence marker.
  final int savedAtSequence;

  /// Stored/verified fingerprint.
  final String fingerprint;
}

/// Decoded replay save payload.
final class DecodedReplaySave {
  /// Creates decoded replay save.
  const DecodedReplaySave({
    required this.replay,
    required this.engineVersion,
    required this.savedAtSequence,
    required this.fingerprint,
  });

  /// Decoded replay payload.
  final ReplaySession replay;

  /// Engine version from envelope.
  final int engineVersion;

  /// Logical save sequence marker.
  final int savedAtSequence;

  /// Stored/verified fingerprint.
  final String fingerprint;
}

/// Encodes a round save envelope.
Map<String, dynamic> encodeSaveRound(
  TriPeaksState state, {
  int engineVersion = 1,
  int? savedAtSequence,
}) {
  final sequence = savedAtSequence ?? state.scoreState.movesCount;
  return _encodeSaveEnvelope(
    engineVersion: engineVersion,
    savedAtSequence: sequence,
    payloadType: 'round',
    payload: state.toMap(),
    fingerprint: stateFingerprint(state),
  );
}

/// Decodes a round save envelope with integrity verification.
SaveDecodeResult<DecodedRoundSave> decodeSaveRound(Map<String, dynamic> map) {
  final parsed = _parseSaveEnvelope(map, expectedPayloadType: 'round');
  if (!parsed.isSuccess) {
    return SaveDecodeResult.failure(parsed.error!);
  }

  final payloadResult = TriPeaksState.tryFromMap(parsed.value!.payload);
  if (!payloadResult.isSuccess) {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: payloadResult.error!.message,
      ),
    );
  }

  final state = payloadResult.value!;
  final recomputed = stateFingerprint(state);
  if (recomputed != parsed.value!.fingerprint) {
    return const SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.corruptSave,
        message: 'Fingerprint mismatch for round payload.',
      ),
    );
  }

  return SaveDecodeResult.success(
    DecodedRoundSave(
      state: state,
      engineVersion: parsed.value!.engineVersion,
      savedAtSequence: parsed.value!.savedAtSequence,
      fingerprint: parsed.value!.fingerprint,
    ),
  );
}

/// Encodes a session save envelope.
Map<String, dynamic> encodeSaveSession(
  TriPeaksSessionState state, {
  int engineVersion = 1,
  int? savedAtSequence,
}) {
  final sequence = savedAtSequence ?? state.currentRound.scoreState.movesCount;
  return _encodeSaveEnvelope(
    engineVersion: engineVersion,
    savedAtSequence: sequence,
    payloadType: 'session',
    payload: state.toMap(),
    fingerprint: sessionFingerprint(state),
  );
}

/// Decodes a session save envelope with integrity verification.
SaveDecodeResult<DecodedSessionSave> decodeSaveSession(
  Map<String, dynamic> map,
) {
  final parsed = _parseSaveEnvelope(map, expectedPayloadType: 'session');
  if (!parsed.isSuccess) {
    return SaveDecodeResult.failure(parsed.error!);
  }

  final payloadResult = TriPeaksSessionState.tryFromMap(parsed.value!.payload);
  if (!payloadResult.isSuccess) {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: payloadResult.error!.message,
      ),
    );
  }

  final state = payloadResult.value!;
  final recomputed = sessionFingerprint(state);
  if (recomputed != parsed.value!.fingerprint) {
    return const SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.corruptSave,
        message: 'Fingerprint mismatch for session payload.',
      ),
    );
  }

  return SaveDecodeResult.success(
    DecodedSessionSave(
      state: state,
      engineVersion: parsed.value!.engineVersion,
      savedAtSequence: parsed.value!.savedAtSequence,
      fingerprint: parsed.value!.fingerprint,
    ),
  );
}

/// Encodes a replay save envelope.
Map<String, dynamic> encodeSaveReplay(
  ReplaySession replay, {
  int engineVersion = 1,
  int? savedAtSequence,
}) {
  final sequence = savedAtSequence ?? replay.entries.length;
  return _encodeSaveEnvelope(
    engineVersion: engineVersion,
    savedAtSequence: sequence,
    payloadType: 'replay',
    payload: replay.toMap(),
    fingerprint: replayFingerprint(replay),
  );
}

/// Decodes a replay save envelope with integrity verification.
SaveDecodeResult<DecodedReplaySave> decodeSaveReplay(Map<String, dynamic> map) {
  final parsed = _parseSaveEnvelope(map, expectedPayloadType: 'replay');
  if (!parsed.isSuccess) {
    return SaveDecodeResult.failure(parsed.error!);
  }

  final payloadResult = ReplaySession.tryFromMap(parsed.value!.payload);
  if (!payloadResult.isSuccess) {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: payloadResult.error!.message,
      ),
    );
  }

  final replay = payloadResult.value!;
  final recomputed = replayFingerprint(replay);
  if (recomputed != parsed.value!.fingerprint) {
    return const SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.corruptSave,
        message: 'Fingerprint mismatch for replay payload.',
      ),
    );
  }

  return SaveDecodeResult.success(
    DecodedReplaySave(
      replay: replay,
      engineVersion: parsed.value!.engineVersion,
      savedAtSequence: parsed.value!.savedAtSequence,
      fingerprint: parsed.value!.fingerprint,
    ),
  );
}

Map<String, dynamic> _encodeSaveEnvelope({
  required int engineVersion,
  required int savedAtSequence,
  required String payloadType,
  required Map<String, dynamic> payload,
  required String fingerprint,
}) {
  return <String, dynamic>{
    'schemaVersion': _saveSchemaVersionV1,
    'type': 'save_envelope',
    'engineVersion': engineVersion,
    'savedAtSequence': savedAtSequence,
    'payloadType': payloadType,
    'payload': payload,
    'fingerprint': fingerprint,
  };
}

final class _ParsedSaveEnvelope {
  const _ParsedSaveEnvelope({
    required this.engineVersion,
    required this.savedAtSequence,
    required this.payload,
    required this.fingerprint,
  });

  final int engineVersion;
  final int savedAtSequence;
  final Map<String, dynamic> payload;
  final String fingerprint;
}

SaveDecodeResult<_ParsedSaveEnvelope> _parseSaveEnvelope(
  Map<String, dynamic> map, {
  required String expectedPayloadType,
}) {
  final schemaVersion = map['schemaVersion'];
  if (schemaVersion is! int) {
    return const SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: 'schemaVersion must be an int.',
      ),
    );
  }
  if (schemaVersion != _saveSchemaVersionV1) {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.unsupportedVersion,
        message: 'Unsupported schemaVersion $schemaVersion.',
      ),
    );
  }

  final type = map['type'];
  final payloadType = map['payloadType'];
  final payload = map['payload'];
  final fingerprint = map['fingerprint'];
  final engineVersion = map['engineVersion'];
  final savedAtSequence = map['savedAtSequence'];

  if (type != 'save_envelope') {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.unknownType,
        message: 'Unknown envelope type $type.',
      ),
    );
  }
  if (payloadType != expectedPayloadType) {
    return SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: 'Expected payloadType "$expectedPayloadType".',
      ),
    );
  }
  if (payload is! Map<String, dynamic> ||
      fingerprint is! String ||
      engineVersion is! int ||
      savedAtSequence is! int) {
    return const SaveDecodeResult.failure(
      SaveDecodeFailure(
        code: SaveDecodeFailureCode.invalidPayload,
        message: 'Invalid save envelope payload fields.',
      ),
    );
  }

  return SaveDecodeResult.success(
    _ParsedSaveEnvelope(
      engineVersion: engineVersion,
      savedAtSequence: savedAtSequence,
      payload: payload,
      fingerprint: fingerprint,
    ),
  );
}
