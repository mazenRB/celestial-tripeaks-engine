import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PeakClearedEvent', () {
    test('serializes and decodes a versioned event', () {
      const event = PeakClearedEvent(peakId: 2, pointsAwarded: 75);

      final Map<String, dynamic> payload = event.toMap();
      final result = PeakClearedEvent.tryFromMap(payload);

      expect(payload, <String, dynamic>{
        'type': 'peak_cleared_event',
        'schemaVersion': 1,
        'peakId': 2,
        'pointsAwarded': 75,
      });
      expect(result.isSuccess, isTrue);
      expect(result.value?.peakId, 2);
      expect(result.value?.pointsAwarded, 75);
    });

    test('rejects an unknown event type', () {
      final result = PeakClearedEvent.tryFromMap(<String, dynamic>{
        'type': 'unknown_event',
        'schemaVersion': 1,
        'peakId': 0,
        'pointsAwarded': 75,
      });

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, DecodeFailureCode.unknownType);
    });

    test('rejects an unsupported schema version', () {
      final result = PeakClearedEvent.tryFromMap(<String, dynamic>{
        'type': 'peak_cleared_event',
        'schemaVersion': 2,
        'peakId': 0,
        'pointsAwarded': 75,
      });

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, DecodeFailureCode.unsupportedSchemaVersion);
    });

    test('rejects invalid peak IDs and non-integer points', () {
      final invalidPeakId = PeakClearedEvent.tryFromMap(<String, dynamic>{
        'type': 'peak_cleared_event',
        'schemaVersion': 1,
        'peakId': 3,
        'pointsAwarded': 75,
      });
      final invalidPoints = PeakClearedEvent.tryFromMap(<String, dynamic>{
        'type': 'peak_cleared_event',
        'schemaVersion': 1,
        'peakId': 0,
        'pointsAwarded': '75',
      });

      expect(invalidPeakId.isSuccess, isFalse);
      expect(invalidPeakId.error?.code, DecodeFailureCode.invalidPayload);
      expect(invalidPoints.isSuccess, isFalse);
      expect(invalidPoints.error?.code, DecodeFailureCode.invalidPayload);
    });
  });
}
