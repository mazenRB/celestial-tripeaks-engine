part of '../tripeaks_engine.dart';

/// Configurable strike-timer behavior for streak expiry.
final class StrikeTimerConfig {
  /// Creates a strike-timer config.
  const StrikeTimerConfig({
    this.enabled = true,
    this.timeoutSeconds = 10,
  }) : assert(timeoutSeconds > 0, 'timeoutSeconds must be > 0.');

  /// Whether strike-timer expirations are enabled.
  final bool enabled;

  /// Timeout value in seconds used by orchestration layers.
  final int timeoutSeconds;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'strike_timer_config',
      'enabled': enabled,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<StrikeTimerConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'strike_timer_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final timeoutSeconds = map['timeoutSeconds'];
    if (enabled is! bool || timeoutSeconds is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        StrikeTimerConfig(
          enabled: enabled,
          timeoutSeconds: timeoutSeconds,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerConfig payload: $error',
        ),
      );
    }
  }
}

/// Runtime strike-timer state for one round.
final class StrikeTimerState {
  /// Creates strike-timer state.
  const StrikeTimerState({
    required this.isArmed,
    required this.deadlineToken,
  });

  /// Initial strike-timer state.
  static const StrikeTimerState initial = StrikeTimerState(
    isArmed: false,
    deadlineToken: 0,
  );

  /// Whether a strike timer is currently armed.
  final bool isArmed;

  /// Monotonic token used to validate expiry events.
  final int deadlineToken;

  /// Returns a copy with optional changes.
  StrikeTimerState copyWith({
    bool? isArmed,
    int? deadlineToken,
  }) {
    return StrikeTimerState(
      isArmed: isArmed ?? this.isArmed,
      deadlineToken: deadlineToken ?? this.deadlineToken,
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'strike_timer_state',
      'isArmed': isArmed,
      'deadlineToken': deadlineToken,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<StrikeTimerState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'strike_timer_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final isArmed = map['isArmed'];
    final deadlineToken = map['deadlineToken'];
    if (isArmed is! bool || deadlineToken is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerState payload.',
        ),
      );
    }
    return DecodeResult.success(
      StrikeTimerState(
        isArmed: isArmed,
        deadlineToken: deadlineToken,
      ),
    );
  }
}

/// Runtime time-bonus timer state for one round.
final class TimeBonusTimerState {
  /// Creates time-bonus timer state.
  const TimeBonusTimerState({
    required this.remainingSeconds,
    required this.deadlineToken,
    required this.stepCount,
  });

  /// Initial time-bonus timer state.
  static const TimeBonusTimerState initial = TimeBonusTimerState(
    remainingSeconds: 0,
    deadlineToken: 0,
    stepCount: 0,
  );

  /// Seconds remaining on the active timer.
  final int remainingSeconds;

  /// Monotonic token used to validate expiry actions.
  final int deadlineToken;

  /// Number of already-multiplied successful moves in the active window.
  final int stepCount;

  /// Returns a copy with optional changes.
  TimeBonusTimerState copyWith({
    int? remainingSeconds,
    int? deadlineToken,
    int? stepCount,
  }) {
    return TimeBonusTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      deadlineToken: deadlineToken ?? this.deadlineToken,
      stepCount: stepCount ?? this.stepCount,
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'time_bonus_timer_state',
      'remainingSeconds': remainingSeconds,
      'deadlineToken': deadlineToken,
      'stepCount': stepCount,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<TimeBonusTimerState> tryFromMap(
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
    if (map['type'] != 'time_bonus_timer_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final remainingSeconds = map['remainingSeconds'];
    final deadlineToken = map['deadlineToken'];
    final stepCount = map['stepCount'];
    if (remainingSeconds is! int ||
        deadlineToken is! int ||
        (stepCount != null && stepCount is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid TimeBonusTimerState payload.',
        ),
      );
    }
    final normalizedStepCount = stepCount is int ? stepCount : 0;
    if (remainingSeconds < 0 || normalizedStepCount < 0) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'TimeBonusTimerState values must be non-negative.',
        ),
      );
    }
    return DecodeResult.success(
      TimeBonusTimerState(
        remainingSeconds: remainingSeconds,
        deadlineToken: deadlineToken,
        stepCount: normalizedStepCount,
      ),
    );
  }
}
