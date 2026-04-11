part of 'tripeaks_engine_internal.dart';

/// Configurable per-round countdown behavior.
final class RoundTimerConfig {
  /// Creates a round-timer config.
  const RoundTimerConfig({
    this.enabled = false,
    this.durationsSecondsByRound = const <int>[],
  });

  /// Whether the round timer system is enabled.
  final bool enabled;

  /// Duration in whole seconds for each 1-based round.
  ///
  /// A value of `0` means that specific round is untimed.
  final List<int> durationsSecondsByRound;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_timer_config',
      'enabled': enabled,
      'durationsSecondsByRound': durationsSecondsByRound,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<RoundTimerConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'round_timer_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final durations = map['durationsSecondsByRound'];
    if (enabled is! bool ||
        durations is! List<dynamic> ||
        durations.any((value) => value is! int || value < 0)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundTimerConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      RoundTimerConfig(
        enabled: enabled,
        durationsSecondsByRound: List<int>.unmodifiable(
          durations.cast<int>(),
        ),
      ),
    );
  }
}

/// Runtime countdown state for one round.
final class RoundTimerState {
  /// Creates round-timer state.
  const RoundTimerState({
    required this.isStarted,
    required this.remainingSeconds,
    required this.deadlineToken,
  });

  /// Untimed/disabled initial state.
  static const RoundTimerState initial = RoundTimerState(
    isStarted: true,
    remainingSeconds: 0,
    deadlineToken: 0,
  );

  /// Whether countdown has been explicitly started.
  final bool isStarted;

  /// Seconds remaining on the active round timer.
  final int remainingSeconds;

  /// Monotonic token used to validate elapsed-time actions.
  final int deadlineToken;

  /// Returns a copy with optional changes.
  RoundTimerState copyWith({
    bool? isStarted,
    int? remainingSeconds,
    int? deadlineToken,
  }) {
    return RoundTimerState(
      isStarted: isStarted ?? this.isStarted,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      deadlineToken: deadlineToken ?? this.deadlineToken,
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_timer_state',
      'isStarted': isStarted,
      'remainingSeconds': remainingSeconds,
      'deadlineToken': deadlineToken,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<RoundTimerState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'round_timer_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final isStarted = map['isStarted'];
    final remainingSeconds = map['remainingSeconds'];
    final deadlineToken = map['deadlineToken'];
    if (isStarted is! bool ||
        remainingSeconds is! int ||
        deadlineToken is! int ||
        remainingSeconds < 0) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundTimerState payload.',
        ),
      );
    }
    return DecodeResult.success(
      RoundTimerState(
        isStarted: isStarted,
        remainingSeconds: remainingSeconds,
        deadlineToken: deadlineToken,
      ),
    );
  }
}

String? _roundTimerConfigValidationMessage(
  RoundTimerConfig config,
  int roundCount,
) {
  if (!config.enabled) {
    return null;
  }
  if (config.durationsSecondsByRound.length != roundCount) {
    return 'roundTimerConfig durations length '
        '${config.durationsSecondsByRound.length} must match '
        'roundCount $roundCount.';
  }
  return null;
}

String? _roundTimerConfigValidationMessageForRound(
  RoundTimerConfig config,
  int roundNumber,
) {
  if (!config.enabled) {
    return null;
  }
  if (roundNumber < 1) {
    return 'roundNumber must be >= 1.';
  }
  if (config.durationsSecondsByRound.length < roundNumber) {
    return 'roundTimerConfig durations length '
        '${config.durationsSecondsByRound.length} must include '
        'roundNumber $roundNumber.';
  }
  return null;
}

int _roundTimerDurationForRound(
  RoundTimerConfig config,
  int roundNumber,
) {
  if (!config.enabled) {
    return 0;
  }
  if (roundNumber < 1 || roundNumber > config.durationsSecondsByRound.length) {
    throw RangeError.range(
      roundNumber,
      1,
      config.durationsSecondsByRound.length,
      'roundNumber',
    );
  }
  return config.durationsSecondsByRound[roundNumber - 1];
}

RoundTimerState _initialRoundTimerState(
  RoundTimerConfig config,
  int roundNumber,
) {
  final duration = _roundTimerDurationForRound(config, roundNumber);
  if (!config.enabled || duration == 0) {
    return RoundTimerState.initial;
  }
  return RoundTimerState(
    isStarted: false,
    remainingSeconds: duration,
    deadlineToken: 0,
  );
}

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
