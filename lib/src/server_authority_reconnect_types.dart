part of '../tripeaks_engine.dart';

/// Versioned reconnect request envelope.
final class ReconnectRequest {
  /// Creates a reconnect request.
  const ReconnectRequest({
    required this.matchId,
    required this.playerId,
    required this.lastKnownAuthoritativeSequence,
    this.lastKnownFingerprint,
    this.schemaVersion = _serializationSchemaV1,
  });

  /// Envelope schema version.
  final int schemaVersion;

  /// Target match id.
  final String matchId;

  /// Reconnecting player id.
  final String playerId;

  /// Last authoritative sequence known by client.
  final int lastKnownAuthoritativeSequence;

  /// Optional client last-known fingerprint.
  final String? lastKnownFingerprint;

  /// Serializes request to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'reconnect_request',
      'matchId': matchId,
      'playerId': playerId,
      'lastKnownAuthoritativeSequence': lastKnownAuthoritativeSequence,
      if (lastKnownFingerprint case final value?) 'lastKnownFingerprint': value,
    };
  }

  /// Decodes request from map without throwing.
  static DecodeResult<ReconnectRequest> tryFromMap(Map<String, dynamic> map) {
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
    if (map['type'] != 'reconnect_request') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final matchId = map['matchId'];
    final playerId = map['playerId'];
    final lastKnownAuthoritativeSequence =
        map['lastKnownAuthoritativeSequence'];
    final lastKnownFingerprint = map['lastKnownFingerprint'];
    if (matchId is! String ||
        playerId is! String ||
        lastKnownAuthoritativeSequence is! int ||
        (lastKnownFingerprint != null && lastKnownFingerprint is! String)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid reconnect request payload.',
        ),
      );
    }

    return DecodeResult.success(
      ReconnectRequest(
        schemaVersion: schemaVersion,
        matchId: matchId,
        playerId: playerId,
        lastKnownAuthoritativeSequence: lastKnownAuthoritativeSequence,
        lastKnownFingerprint: lastKnownFingerprint as String?,
      ),
    );
  }
}

/// Typed reconnect failure code.
enum ReconnectFailureCode {
  matchIdMismatch,
  playerNotFound,
}

/// Typed reconnect failure details.
final class ReconnectFailure {
  /// Creates reconnect failure.
  const ReconnectFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly failure code.
  final ReconnectFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Result for reconnect handling.
final class ReconnectResult {
  /// Creates reconnect result.
  const ReconnectResult({
    required this.isSuccess,
    this.failure,
    this.snapshot,
    this.authoritativeSequence,
    this.authoritativeFingerprint,
    this.mustFullyResync = false,
  });

  /// Whether reconnect request was valid.
  final bool isSuccess;

  /// Failure details when not successful.
  final ReconnectFailure? failure;

  /// Current authoritative match snapshot.
  final MatchState? snapshot;

  /// Current authoritative sequence.
  final int? authoritativeSequence;

  /// Player authoritative fingerprint.
  final String? authoritativeFingerprint;

  /// Whether client should fully resync due to fingerprint mismatch.
  final bool mustFullyResync;
}
