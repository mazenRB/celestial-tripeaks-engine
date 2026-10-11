part of 'tripeaks_engine_internal.dart';

/// Describes one peak newly cleared by a successful round action.
final class PeakClearedEvent {
  /// Creates an event for [peakId] and the points awarded for clearing it.
  const PeakClearedEvent({
    required this.peakId,
    required this.pointsAwarded,
  });

  /// Stable zero-based identifier of the cleared peak.
  final int peakId;

  /// Points credited for clearing this peak.
  final int pointsAwarded;

  /// Serializes this event as a versioned map.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': 'peak_cleared_event',
        'schemaVersion': 1,
        'peakId': peakId,
        'pointsAwarded': pointsAwarded,
      };

  /// Decodes a versioned event map without throwing on invalid payloads.
  static DecodeResult<PeakClearedEvent> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['type'] != 'peak_cleared_event') {
      return const DecodeResult<PeakClearedEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown peak cleared event type.',
        ),
      );
    }

    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      return const DecodeResult<PeakClearedEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid peak cleared event schema version.',
        ),
      );
    }
    if (schemaVersion != 1) {
      return const DecodeResult<PeakClearedEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported peak cleared event schema version.',
        ),
      );
    }

    final peakId = map['peakId'];
    final pointsAwarded = map['pointsAwarded'];
    if (peakId is! int || peakId < 0 || peakId > 2 || pointsAwarded is! int) {
      return const DecodeResult<PeakClearedEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid peak cleared event payload.',
        ),
      );
    }

    return DecodeResult<PeakClearedEvent>.success(
      PeakClearedEvent(peakId: peakId, pointsAwarded: pointsAwarded),
    );
  }
}
