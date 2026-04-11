part of 'tripeaks_engine_internal.dart';

const int _serializationSchemaV1 = 1;

/// Returns a stable deterministic fingerprint for a round [state].
///
/// The fingerprint is derived from canonical serialization and a stable
/// platform-independent hash algorithm.
String stateFingerprint(TriPeaksState state) {
  return _fingerprintFromMap(state.toMap());
}

/// Returns a stable deterministic fingerprint for a full [state] session.
String sessionFingerprint(TriPeaksSessionState state) {
  return _fingerprintFromMap(state.toMap());
}

/// Returns a deterministic fingerprint of replayed session state.
///
/// If [stepN] is omitted, all replay entries are used.
String replayFingerprint(
  ReplaySession replay, {
  int? stepN,
}) {
  final step = stepN ?? replay.entries.length;
  final state = replayStep(replay, step);
  return sessionFingerprint(state);
}

/// Typed decode failure codes.
enum DecodeFailureCode {
  unsupportedSchemaVersion,
  invalidPayload,
  unknownType,
}

/// Typed decode failure details.
final class DecodeFailure {
  /// Creates decode failure details.
  const DecodeFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final DecodeFailureCode code;

  /// Human-friendly error message.
  final String message;
}

/// Typed decode result.
final class DecodeResult<T> {
  /// Creates successful decode result.
  const DecodeResult.success(this.value)
      : error = null,
        isSuccess = true;

  /// Creates failed decode result.
  const DecodeResult.failure(this.error)
      : value = null,
        isSuccess = false;

  /// Decoded value for success.
  final T? value;

  /// Failure details for errors.
  final DecodeFailure? error;

  /// Whether decoding succeeded.
  final bool isSuccess;
}

/// State envelope for schema version 1.
final class StateEnvelopeV1 {
  /// Creates v1 state envelope.
  const StateEnvelopeV1({
    required this.type,
    this.roundState,
    this.sessionState,
  });

  /// Envelope type discriminator.
  final String type;

  /// Round state when [type] is `tripeaks_round_state`.
  final TriPeaksState? roundState;

  /// Session state when [type] is `tripeaks_session_state`.
  final TriPeaksSessionState? sessionState;
}

/// Action envelope for schema version 1.
final class ActionEnvelopeV1 {
  /// Creates v1 action envelope.
  const ActionEnvelopeV1({
    required this.type,
    this.roundAction,
    this.sessionAction,
  });

  /// Envelope type discriminator.
  final String type;

  /// Round action when [type] is `tripeaks_round_action`.
  final TriPeaksAction? roundAction;

  /// Session action when [type] is `tripeaks_session_action`.
  final TriPeaksSessionAction? sessionAction;
}

/// Central state decoder with schema migration hook.
DecodeResult<StateEnvelopeV1> decodeStateEnvelope(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'schemaVersion must be an int.',
      ),
    );
  }

  if (schemaVersion == _serializationSchemaV1) {
    return _decodeStateEnvelopeV1(json);
  }

  return DecodeResult.failure(
    DecodeFailure(
      code: DecodeFailureCode.unsupportedSchemaVersion,
      message: 'Unsupported schemaVersion $schemaVersion.',
    ),
  );
}

DecodeResult<StateEnvelopeV1> _decodeStateEnvelopeV1(
    Map<String, dynamic> json) {
  final type = json['type'];
  if (type is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'State envelope type must be a string.',
      ),
    );
  }

  switch (type) {
    case 'tripeaks_round_state':
      final decoded = TriPeaksState.tryFromMap(json);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      return DecodeResult.success(
        StateEnvelopeV1(type: type, roundState: decoded.value!),
      );

    case 'tripeaks_session_state':
      final decoded = TriPeaksSessionState.tryFromMap(json);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      return DecodeResult.success(
        StateEnvelopeV1(type: type, sessionState: decoded.value!),
      );

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown state type "$type".',
        ),
      );
  }
}

/// Central action decoder with schema migration hook.
DecodeResult<ActionEnvelopeV1> decodeActionEnvelope(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'schemaVersion must be an int.',
      ),
    );
  }

  if (schemaVersion == _serializationSchemaV1) {
    return _decodeActionEnvelopeV1(json);
  }

  return DecodeResult.failure(
    DecodeFailure(
      code: DecodeFailureCode.unsupportedSchemaVersion,
      message: 'Unsupported schemaVersion $schemaVersion.',
    ),
  );
}

DecodeResult<ActionEnvelopeV1> _decodeActionEnvelopeV1(
  Map<String, dynamic> json,
) {
  final type = json['type'];
  if (type is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'Action envelope type must be a string.',
      ),
    );
  }

  switch (type) {
    case 'tripeaks_round_action':
      final decoded = tryDecodeRoundAction(json);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      return DecodeResult.success(
        ActionEnvelopeV1(type: type, roundAction: decoded.value!),
      );

    case 'tripeaks_session_action':
      final decoded = tryDecodeSessionAction(json);
      if (!decoded.isSuccess) {
        return DecodeResult.failure(decoded.error!);
      }
      return DecodeResult.success(
        ActionEnvelopeV1(type: type, sessionAction: decoded.value!),
      );

    default:
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown action type "$type".',
        ),
      );
  }
}

String _fingerprintFromMap(Map<String, dynamic> map) {
  final canonical = jsonEncode(_canonicalizeJsonValue(map));
  final hash = _fnv1a32Full(canonical);
  return hash.toRadixString(16).padLeft(8, '0');
}

Object? _canonicalizeJsonValue(Object? value) {
  switch (value) {
    case null:
      return null;
    case bool():
      return value;
    case num():
      return value;
    case String():
      return value;
    case List<dynamic>():
      return value
          .map<Object?>((item) => _canonicalizeJsonValue(item))
          .toList(growable: false);
    case Map<dynamic, dynamic>():
      final entries = value.entries
          .map((entry) => (entry.key.toString(), entry.value))
          .toList(growable: false)
        ..sort((a, b) => a.$1.compareTo(b.$1));
      final out = <String, Object?>{};
      for (final entry in entries) {
        out[entry.$1] = _canonicalizeJsonValue(entry.$2);
      }
      return out;
    default:
      throw StateError('Unsupported canonical JSON value type: $value');
  }
}

int _fnv1a32Full(String input) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
