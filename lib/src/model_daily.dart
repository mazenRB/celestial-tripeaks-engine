part of '../tripeaks_engine.dart';

/// Immutable calendar date without timezone/time-of-day.
final class DateOnly {
  /// Creates a date from explicit [year], [month], and [day].
  const DateOnly(this.year, this.month, this.day)
      : assert(month >= 1 && month <= 12),
        assert(day >= 1 && day <= 31);

  /// Creates a date from a [DateTime] by taking only Y-M-D components.
  factory DateOnly.fromDateTime(DateTime dateTime) {
    return DateOnly(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Gregorian calendar year.
  final int year;

  /// Gregorian month in range `1..12`.
  final int month;

  /// Day-of-month in range `1..31`.
  final int day;

  /// Returns ISO-like `YYYY-MM-DD`.
  String toIsoString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DateOnly &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  /// Serializes date to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'date_only',
      'year': year,
      'month': month,
      'day': day,
    };
  }

  /// Decodes date from map without throwing.
  static DecodeResult<DateOnly> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'date_only') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final year = map['year'];
    final month = map['month'];
    final day = map['day'];
    if (year is! int || month is! int || day is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'DateOnly year/month/day must be ints.',
        ),
      );
    }
    return DecodeResult.success(DateOnly(year, month, day));
  }
}

/// Config for daily challenge seed generation.
final class DailyChallengeConfig {
  /// Creates daily challenge config.
  const DailyChallengeConfig({
    required this.namespaceId,
    required this.modeId,
    this.schemaVersion = 1,
    this.roundCount,
  });

  /// Creates a daily config from a canonical engine-owned preset.
  factory DailyChallengeConfig.forPreset({
    required String namespaceId,
    required TriPeaksModePreset preset,
    int schemaVersion = 1,
    int? roundCount,
  }) {
    return DailyChallengeConfig(
      namespaceId: namespaceId,
      modeId: preset.modeId,
      schemaVersion: schemaVersion,
      roundCount: roundCount,
    );
  }

  /// Namespace to avoid collisions between app variants/environments.
  final String namespaceId;

  /// Mode id for different daily playlists.
  final String modeId;

  /// Explicit version for intentional sequence changes.
  final int schemaVersion;

  /// Optional number of rounds for session challenges.
  ///
  /// Supported values are currently `1`, `3`, `6`, and `10`.
  final int? roundCount;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'daily_challenge_config',
      'namespaceId': namespaceId,
      'modeId': modeId,
      'dailySchemaVersion': schemaVersion,
      if (roundCount case final value?) 'roundCount': value,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<DailyChallengeConfig> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'daily_challenge_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final namespaceId = map['namespaceId'];
    final modeId = map['modeId'];
    final dailySchemaVersion = map['dailySchemaVersion'];
    final roundCount = map['roundCount'];
    if (namespaceId is! String ||
        modeId is! String ||
        dailySchemaVersion is! int ||
        (roundCount != null && roundCount is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid DailyChallengeConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      DailyChallengeConfig(
        namespaceId: namespaceId,
        modeId: modeId,
        schemaVersion: dailySchemaVersion,
        roundCount: roundCount as int?,
      ),
    );
  }
}
