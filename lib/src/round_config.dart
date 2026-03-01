part of '../tripeaks_engine.dart';

/// Configurable scoring values for round actions.
final class ScoreConfig {
  /// Creates a scoring config.
  const ScoreConfig({
    this.pointsTableauToWaste = 5,
    this.pointsDrawFromStock = 0,
    this.penaltyInvalidAction = 0,
    this.pointsPeakCleared = 0,
    this.pointsPerRemainingStockCardOnWin = 0,
    this.multiplierMode = ScoreMultiplierMode.streak,
    this.streakStepSize = 999999,
    this.multiplierStepIncrement = 0,
    this.multiplierMax = 1,
    this.timeBonusSecondsPerMove = 2,
    this.timeBonusMaxSeconds = 10,
  });

  /// Points added when a tableau card is moved to waste.
  final int pointsTableauToWaste;

  /// Points added when drawing one card from stock.
  final int pointsDrawFromStock;

  /// Delta applied for invalid actions.
  ///
  /// This can be negative to represent penalties.
  final int penaltyInvalidAction;

  /// Points awarded once when a peak is fully cleared.
  final int pointsPeakCleared;

  /// Bonus points awarded per remaining stock card when a round is won.
  final int pointsPerRemainingStockCardOnWin;

  /// Selects which multiplier system is active for scoring.
  final ScoreMultiplierMode multiplierMode;

  /// Number of streak points required to advance one multiplier step.
  ///
  /// Large values effectively disable step-based multiplier growth.
  final int streakStepSize;

  /// Amount added to multiplier per completed step.
  final int multiplierStepIncrement;

  /// Maximum multiplier value.
  final int multiplierMax;

  /// Seconds added per valid tableau move in time-bonus mode.
  final int timeBonusSecondsPerMove;

  /// Maximum seconds the time-bonus timer can hold.
  final int timeBonusMaxSeconds;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_config',
      'pointsTableauToWaste': pointsTableauToWaste,
      'pointsDrawFromStock': pointsDrawFromStock,
      'penaltyInvalidAction': penaltyInvalidAction,
      'pointsPeakCleared': pointsPeakCleared,
      'pointsPerRemainingStockCardOnWin': pointsPerRemainingStockCardOnWin,
      'multiplierMode': multiplierMode.name,
      'streakStepSize': streakStepSize,
      'multiplierStepIncrement': multiplierStepIncrement,
      'multiplierMax': multiplierMax,
      'timeBonusSecondsPerMove': timeBonusSecondsPerMove,
      'timeBonusMaxSeconds': timeBonusMaxSeconds,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<ScoreConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'score_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final a = map['pointsTableauToWaste'];
    final b = map['pointsDrawFromStock'];
    final c = map['penaltyInvalidAction'];
    final d = map['pointsPeakCleared'];
    final remainingStockBonus = map['pointsPerRemainingStockCardOnWin'];
    final multiplierMode = map['multiplierMode'];
    final streakStepSize = map['streakStepSize'];
    final multiplierStepIncrement = map['multiplierStepIncrement'];
    final multiplierMax = map['multiplierMax'];
    final timeBonusSecondsPerMove = map['timeBonusSecondsPerMove'];
    final timeBonusMaxSeconds = map['timeBonusMaxSeconds'];
    if (a is! int ||
        b is! int ||
        c is! int ||
        d is! int ||
        (remainingStockBonus != null && remainingStockBonus is! int) ||
        (multiplierMode != null && multiplierMode is! String) ||
        (streakStepSize != null && streakStepSize is! int) ||
        (multiplierStepIncrement != null && multiplierStepIncrement is! int) ||
        (multiplierMax != null && multiplierMax is! int) ||
        (timeBonusSecondsPerMove != null && timeBonusSecondsPerMove is! int) ||
        (timeBonusMaxSeconds != null && timeBonusMaxSeconds is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreConfig payload.',
        ),
      );
    }
    ScoreMultiplierMode resolvedMode = ScoreMultiplierMode.streak;
    if (multiplierMode case final modeName?) {
      try {
        resolvedMode = ScoreMultiplierMode.values.byName(modeName);
      } on Object catch (error) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Invalid multiplierMode: $error',
          ),
        );
      }
    }
    return DecodeResult.success(
      ScoreConfig(
        pointsTableauToWaste: a,
        pointsDrawFromStock: b,
        penaltyInvalidAction: c,
        pointsPeakCleared: d,
        pointsPerRemainingStockCardOnWin: remainingStockBonus as int? ?? 0,
        multiplierMode: resolvedMode,
        streakStepSize: streakStepSize as int? ?? 999999,
        multiplierStepIncrement: multiplierStepIncrement as int? ?? 0,
        multiplierMax: multiplierMax as int? ?? 1,
        timeBonusSecondsPerMove: timeBonusSecondsPerMove as int? ?? 2,
        timeBonusMaxSeconds: timeBonusMaxSeconds as int? ?? 10,
      ),
    );
  }
}

/// Selects which multiplier system is active for scoring.
enum ScoreMultiplierMode {
  streak,
  timeBonus,
}

/// Component-level explanation for one applied score delta.
final class ScoreDeltaBreakdown {
  /// Creates a score delta breakdown.
  const ScoreDeltaBreakdown({
    required this.tableauBasePoints,
    required this.multiplierExtraPoints,
    required this.peakBonusPoints,
    required this.drawPoints,
    required this.invalidPenaltyPoints,
    required this.endRoundRemainingStockBonusPoints,
    required this.appliedMultiplier,
    required this.totalDelta,
  });

  /// Zero-value breakdown used for non-scoring actions.
  static const ScoreDeltaBreakdown zero = ScoreDeltaBreakdown(
    tableauBasePoints: 0,
    multiplierExtraPoints: 0,
    peakBonusPoints: 0,
    drawPoints: 0,
    invalidPenaltyPoints: 0,
    endRoundRemainingStockBonusPoints: 0,
    appliedMultiplier: 1,
    totalDelta: 0,
  );

  /// Base points from successful tableau removal.
  final int tableauBasePoints;

  /// Additional points granted by multiplier.
  final int multiplierExtraPoints;

  /// Bonus points awarded for newly cleared peaks.
  final int peakBonusPoints;

  /// Points from drawing one card from stock.
  final int drawPoints;

  /// Penalty from invalid actions (0 or negative).
  final int invalidPenaltyPoints;

  /// Bonus points from remaining stock when a round is won.
  final int endRoundRemainingStockBonusPoints;

  /// Multiplier applied to the action's scoring computation.
  final int appliedMultiplier;

  /// Final score delta for the action.
  final int totalDelta;

  /// Serializes score breakdown to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_delta_breakdown',
      'tableauBasePoints': tableauBasePoints,
      'multiplierExtraPoints': multiplierExtraPoints,
      'peakBonusPoints': peakBonusPoints,
      'drawPoints': drawPoints,
      'invalidPenaltyPoints': invalidPenaltyPoints,
      'endRoundRemainingStockBonusPoints': endRoundRemainingStockBonusPoints,
      'appliedMultiplier': appliedMultiplier,
      'totalDelta': totalDelta,
    };
  }

  /// Decodes score breakdown from map without throwing.
  static DecodeResult<ScoreDeltaBreakdown> tryFromMap(
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
    if (map['type'] != 'score_delta_breakdown') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final tableauBasePoints = map['tableauBasePoints'];
    final multiplierExtraPoints = map['multiplierExtraPoints'];
    final peakBonusPoints = map['peakBonusPoints'];
    final drawPoints = map['drawPoints'];
    final invalidPenaltyPoints = map['invalidPenaltyPoints'];
    final endRoundRemainingStockBonusPoints =
        map['endRoundRemainingStockBonusPoints'];
    final appliedMultiplier = map['appliedMultiplier'];
    final totalDelta = map['totalDelta'];
    if (tableauBasePoints is! int ||
        multiplierExtraPoints is! int ||
        peakBonusPoints is! int ||
        drawPoints is! int ||
        invalidPenaltyPoints is! int ||
        (endRoundRemainingStockBonusPoints != null &&
            endRoundRemainingStockBonusPoints is! int) ||
        appliedMultiplier is! int ||
        totalDelta is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreDeltaBreakdown payload.',
        ),
      );
    }
    return DecodeResult.success(
      ScoreDeltaBreakdown(
        tableauBasePoints: tableauBasePoints,
        multiplierExtraPoints: multiplierExtraPoints,
        peakBonusPoints: peakBonusPoints,
        drawPoints: drawPoints,
        invalidPenaltyPoints: invalidPenaltyPoints,
        endRoundRemainingStockBonusPoints:
            endRoundRemainingStockBonusPoints as int? ?? 0,
        appliedMultiplier: appliedMultiplier,
        totalDelta: totalDelta,
      ),
    );
  }
}

/// Scoring state for one round.
final class ScoreState {
  /// Creates a score state snapshot.
  const ScoreState({
    required this.totalScore,
    required this.movesCount,
    required this.lastDelta,
    required this.currentMultiplier,
    required this.lastBreakdown,
  });

  /// Initial score state at round start.
  static const ScoreState initial = ScoreState(
    totalScore: 0,
    movesCount: 0,
    lastDelta: 0,
    currentMultiplier: 1,
    lastBreakdown: ScoreDeltaBreakdown.zero,
  );

  /// Total accumulated score for the round.
  final int totalScore;

  /// Count of scoring applications processed in this round.
  final int movesCount;

  /// Last applied score delta.
  final int lastDelta;

  /// Multiplier used on the most recent accepted action.
  final int currentMultiplier;

  /// Component breakdown for the most recent accepted action.
  final ScoreDeltaBreakdown lastBreakdown;

  /// Returns the next score state after applying [delta].
  ScoreState applyDelta(
    int delta, {
    int appliedMultiplier = 1,
    ScoreDeltaBreakdown? breakdown,
  }) {
    final normalizedMultiplier = appliedMultiplier < 1 ? 1 : appliedMultiplier;
    final nextBreakdown = breakdown ??
        ScoreDeltaBreakdown(
          tableauBasePoints: delta > 0 ? delta : 0,
          multiplierExtraPoints: 0,
          peakBonusPoints: 0,
          drawPoints: 0,
          invalidPenaltyPoints: delta < 0 ? delta : 0,
          endRoundRemainingStockBonusPoints: 0,
          appliedMultiplier: normalizedMultiplier,
          totalDelta: delta,
        );
    return ScoreState(
      totalScore: totalScore + delta,
      movesCount: movesCount + 1,
      lastDelta: delta,
      currentMultiplier: normalizedMultiplier,
      lastBreakdown: nextBreakdown,
    );
  }

  /// Returns a score state that records a non-scoring accepted action.
  ScoreState withNoScoreChange({
    required int appliedMultiplier,
    required ScoreDeltaBreakdown breakdown,
  }) {
    final normalizedMultiplier = appliedMultiplier < 1 ? 1 : appliedMultiplier;
    return ScoreState(
      totalScore: totalScore,
      movesCount: movesCount,
      lastDelta: breakdown.totalDelta,
      currentMultiplier: normalizedMultiplier,
      lastBreakdown: breakdown,
    );
  }

  /// Serializes score state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_state',
      'totalScore': totalScore,
      'movesCount': movesCount,
      'lastDelta': lastDelta,
      'currentMultiplier': currentMultiplier,
      'lastBreakdown': lastBreakdown.toMap(),
    };
  }

  /// Decodes score state from map without throwing.
  static DecodeResult<ScoreState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'score_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final totalScore = map['totalScore'];
    final movesCount = map['movesCount'];
    final lastDelta = map['lastDelta'];
    if (totalScore is! int || movesCount is! int || lastDelta is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreState payload.',
        ),
      );
    }
    final currentMultiplier = map['currentMultiplier'];
    if (currentMultiplier != null && currentMultiplier is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreState payload.',
        ),
      );
    }
    final breakdownMap = map['lastBreakdown'];
    ScoreDeltaBreakdown breakdown;
    if (breakdownMap == null) {
      breakdown = ScoreDeltaBreakdown(
        tableauBasePoints: lastDelta > 0 ? lastDelta : 0,
        multiplierExtraPoints: 0,
        peakBonusPoints: 0,
        drawPoints: 0,
        invalidPenaltyPoints: lastDelta < 0 ? lastDelta : 0,
        endRoundRemainingStockBonusPoints: 0,
        appliedMultiplier: currentMultiplier as int? ?? 1,
        totalDelta: lastDelta,
      );
    } else if (breakdownMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreState payload.',
        ),
      );
    } else {
      final breakdownResult = ScoreDeltaBreakdown.tryFromMap(breakdownMap);
      if (!breakdownResult.isSuccess) {
        return DecodeResult.failure(breakdownResult.error!);
      }
      breakdown = breakdownResult.value!;
    }
    return DecodeResult.success(
      ScoreState(
        totalScore: totalScore,
        movesCount: movesCount,
        lastDelta: lastDelta,
        currentMultiplier: currentMultiplier as int? ?? 1,
        lastBreakdown: breakdown,
      ),
    );
  }
}

/// Streak tracking state for one round.
final class StreakState {
  /// Creates a streak state snapshot.
  const StreakState({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastActionTick,
  });

  /// Initial streak state at round start.
  static const StreakState initial = StreakState(
    currentStreak: 0,
    bestStreak: 0,
    lastActionTick: null,
  );

  /// Current active streak count.
  final int currentStreak;

  /// Best streak reached so far in this round.
  final int bestStreak;

  /// Last logical tick where a tableau-to-waste success happened.
  final int? lastActionTick;

  /// Returns a copy with optional changes.
  StreakState copyWith({
    int? currentStreak,
    int? bestStreak,
    int? lastActionTick,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastActionTick: lastActionTick ?? this.lastActionTick,
    );
  }

  /// Serializes streak state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'streak_state',
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      if (lastActionTick case final value?) 'lastActionTick': value,
    };
  }

  /// Decodes streak state from map without throwing.
  static DecodeResult<StreakState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'streak_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final currentStreak = map['currentStreak'];
    final bestStreak = map['bestStreak'];
    final lastActionTick = map['lastActionTick'];
    if (currentStreak is! int ||
        bestStreak is! int ||
        (lastActionTick != null && lastActionTick is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StreakState payload.',
        ),
      );
    }
    return DecodeResult.success(
      StreakState(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        lastActionTick: lastActionTick as int?,
      ),
    );
  }
}

/// Configurable round mechanics rules.
final class RoundRulesConfig {
  /// Creates a round rules config.
  const RoundRulesConfig({this.aceKingWrapAround = true});

  /// Whether ace and king are treated as adjacent.
  ///
  /// Set this to `true` for easy/wrap modes.
  final bool aceKingWrapAround;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_rules_config',
      'aceKingWrapAround': aceKingWrapAround,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<RoundRulesConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'round_rules_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final wrap = map['aceKingWrapAround'];
    if (wrap is! bool) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundRulesConfig payload.',
        ),
      );
    }
    return DecodeResult.success(RoundRulesConfig(aceKingWrapAround: wrap));
  }
}

/// Configurable undo behavior for a round.
final class UndoConfig {
  /// Creates an undo config.
  const UndoConfig({
    this.enabled = true,
    this.maxSteps = 10,
  }) : assert(maxSteps >= 0, 'maxSteps must be >= 0.');

  /// Whether undo is enabled.
  final bool enabled;

  /// Maximum number of snapshots retained for undo.
  final int maxSteps;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'undo_config',
      'enabled': enabled,
      'maxSteps': maxSteps,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<UndoConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'undo_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final maxSteps = map['maxSteps'];
    if (enabled is! bool || maxSteps is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid UndoConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
        UndoConfig(enabled: enabled, maxSteps: maxSteps));
  }
}

/// Configurable streak behavior for a round.
final class StreakConfig {
  /// Creates a streak config.
  const StreakConfig({
    this.enabled = true,
    this.resetOnDraw = true,
    this.resetOnInvalidAction = true,
    this.maxGapTicks,
  }) : assert(maxGapTicks == null || maxGapTicks >= 0);

  /// Whether streak tracking is enabled.
  final bool enabled;

  /// Whether streak resets on successful draw actions.
  final bool resetOnDraw;

  /// Whether streak resets when an action is invalid.
  final bool resetOnInvalidAction;

  /// Optional maximum allowed gap between streak actions.
  ///
  /// If set and `(tick - lastActionTick) > maxGapTicks`, the current streak
  /// resets before processing the incoming action.
  final int? maxGapTicks;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'streak_config',
      'enabled': enabled,
      'resetOnDraw': resetOnDraw,
      'resetOnInvalidAction': resetOnInvalidAction,
      if (maxGapTicks case final value?) 'maxGapTicks': value,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<StreakConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'streak_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final resetOnDraw = map['resetOnDraw'];
    final resetOnInvalidAction = map['resetOnInvalidAction'];
    final maxGapTicks = map['maxGapTicks'];
    if (enabled is! bool ||
        resetOnDraw is! bool ||
        resetOnInvalidAction is! bool ||
        (maxGapTicks != null && maxGapTicks is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StreakConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      StreakConfig(
        enabled: enabled,
        resetOnDraw: resetOnDraw,
        resetOnInvalidAction: resetOnInvalidAction,
        maxGapTicks: maxGapTicks as int?,
      ),
    );
  }
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

/// Configurable bonus-slot behavior linked to streak progression.
enum BonusSlotSpawnPolicy {
  joker,
  tierFixedRank,
  tierRandomRank,
}

/// Tier used when spawning deterministic anchor cards.
enum BonusSlotAnchorTier {
  low,
  high,
}

/// Configurable bonus-slot behavior linked to streak progression.
final class BonusSlotsConfig {
  /// Creates bonus-slots config.
  const BonusSlotsConfig({
    this.enabled = true,
    this.spawnPolicy = BonusSlotSpawnPolicy.tierFixedRank,
    this.defaultAnchorTierWhenUnknown = BonusSlotAnchorTier.low,
    this.lowTierAnchorRank = Rank.six,
    this.highTierAnchorRank = Rank.queen,
    this.jokerAcceptsAnyRank = true,
    this.jokerConsumedOnFirstUse = true,
    this.spawnOnOpenSlot2AtStreak = 3,
    this.spawnOnOpenSlot3AtStreak = 6,
    this.closeOnDraw = true,
    this.closeOnInvalidAction = true,
    this.maxSlots = 3,
  })  : assert(spawnOnOpenSlot2AtStreak >= 1),
        assert(spawnOnOpenSlot3AtStreak >= 1),
        assert(
          lowTierAnchorRank != Rank.ace &&
              lowTierAnchorRank != Rank.jack &&
              lowTierAnchorRank != Rank.queen &&
              lowTierAnchorRank != Rank.king,
        ),
        assert(
          highTierAnchorRank == Rank.ace ||
              highTierAnchorRank == Rank.jack ||
              highTierAnchorRank == Rank.queen ||
              highTierAnchorRank == Rank.king,
        ),
        assert(maxSlots == 3);

  /// Whether bonus slots logic is enabled.
  final bool enabled;

  /// Slot-open spawn behavior.
  final BonusSlotSpawnPolicy spawnPolicy;

  /// Default tier used when no successful tableau move exists yet.
  final BonusSlotAnchorTier defaultAnchorTierWhenUnknown;

  /// Fixed anchor rank for LOW tier.
  final Rank lowTierAnchorRank;

  /// Fixed anchor rank for HIGH tier.
  final Rank highTierAnchorRank;

  /// Whether joker anchors allow any rank to be placed.
  final bool jokerAcceptsAnyRank;

  /// Whether joker anchors are consumed when first used.
  final bool jokerConsumedOnFirstUse;

  /// Streak threshold that unlocks/spawns slot 2.
  final int spawnOnOpenSlot2AtStreak;

  /// Streak threshold that unlocks/spawns slot 3.
  final int spawnOnOpenSlot3AtStreak;

  /// Whether draw actions close unlocked bonus slots.
  final bool closeOnDraw;

  /// Whether invalid actions close unlocked bonus slots.
  final bool closeOnInvalidAction;

  /// Max supported slot count.
  ///
  /// Slot1 is always available.
  final int maxSlots;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'bonus_slots_config',
      'enabled': enabled,
      'spawnPolicy': spawnPolicy.name,
      'defaultAnchorTierWhenUnknown': defaultAnchorTierWhenUnknown.name,
      'lowTierAnchorRank': lowTierAnchorRank.name,
      'highTierAnchorRank': highTierAnchorRank.name,
      'jokerAcceptsAnyRank': jokerAcceptsAnyRank,
      'jokerConsumedOnFirstUse': jokerConsumedOnFirstUse,
      'spawnOnOpenSlot2AtStreak': spawnOnOpenSlot2AtStreak,
      'spawnOnOpenSlot3AtStreak': spawnOnOpenSlot3AtStreak,
      'closeOnDraw': closeOnDraw,
      'closeOnInvalidAction': closeOnInvalidAction,
      'maxSlots': maxSlots,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<BonusSlotsConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'bonus_slots_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final spawnPolicy = map['spawnPolicy'] ?? BonusSlotSpawnPolicy.joker.name;
    final defaultAnchorTierWhenUnknown =
        map['defaultAnchorTierWhenUnknown'] ?? BonusSlotAnchorTier.low.name;
    final lowTierAnchorRank = map['lowTierAnchorRank'] ?? Rank.six.name;
    final highTierAnchorRank = map['highTierAnchorRank'] ?? Rank.queen.name;
    final jokerAcceptsAnyRank = map['jokerAcceptsAnyRank'] ?? true;
    final jokerConsumedOnFirstUse = map['jokerConsumedOnFirstUse'] ?? true;
    final spawnOnOpenSlot2AtStreak =
        map['spawnOnOpenSlot2AtStreak'] ?? map['unlockAtStreakSlot2'];
    final spawnOnOpenSlot3AtStreak =
        map['spawnOnOpenSlot3AtStreak'] ?? map['unlockAtStreakSlot3'];
    final closeOnDraw = map['closeOnDraw'];
    final closeOnInvalidAction = map['closeOnInvalidAction'];
    final maxSlots = map['maxSlots'];
    if (enabled is! bool ||
        spawnPolicy is! String ||
        defaultAnchorTierWhenUnknown is! String ||
        lowTierAnchorRank is! String ||
        highTierAnchorRank is! String ||
        jokerAcceptsAnyRank is! bool ||
        jokerConsumedOnFirstUse is! bool ||
        spawnOnOpenSlot2AtStreak is! int ||
        spawnOnOpenSlot3AtStreak is! int ||
        closeOnDraw is! bool ||
        closeOnInvalidAction is! bool ||
        maxSlots is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        BonusSlotsConfig(
          enabled: enabled,
          spawnPolicy: BonusSlotSpawnPolicy.values.byName(spawnPolicy),
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.values.byName(
            defaultAnchorTierWhenUnknown,
          ),
          lowTierAnchorRank: Rank.values.byName(lowTierAnchorRank),
          highTierAnchorRank: Rank.values.byName(highTierAnchorRank),
          jokerAcceptsAnyRank: jokerAcceptsAnyRank,
          jokerConsumedOnFirstUse: jokerConsumedOnFirstUse,
          spawnOnOpenSlot2AtStreak: spawnOnOpenSlot2AtStreak,
          spawnOnOpenSlot3AtStreak: spawnOnOpenSlot3AtStreak,
          closeOnDraw: closeOnDraw,
          closeOnInvalidAction: closeOnInvalidAction,
          maxSlots: maxSlots,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsConfig payload: $error',
        ),
      );
    }
  }
}

/// Bonus-slots runtime state for one round.
final class BonusSlotsState {
  /// Creates bonus-slots state.
  const BonusSlotsState({
    required this.slots,
    required this.openSlotsCount,
    required this.lastUsedSlot,
  });

  /// Initial bonus-slots state.
  static const BonusSlotsState initial = BonusSlotsState(
    slots: <List<Card>>[
      <Card>[],
      <Card>[],
      <Card>[],
    ],
    openSlotsCount: 1,
    lastUsedSlot: null,
  );

  /// A 3-slot set of waste stacks from bottom to top.
  ///
  /// Slot indices are 1-based in APIs and 0-based in this list.
  final List<List<Card>> slots;

  /// Number of open slots, in range 1..3.
  final int openSlotsCount;

  /// Last used slot index (1-based), when explicit slot-use action occurs.
  final int? lastUsedSlot;

  /// Returns a copy with optional changes.
  BonusSlotsState copyWith({
    List<List<Card>>? slots,
    int? openSlotsCount,
    int? lastUsedSlot,
    bool clearLastUsedSlot = false,
  }) {
    return BonusSlotsState(
      slots: slots ?? this.slots,
      openSlotsCount: openSlotsCount ?? this.openSlotsCount,
      lastUsedSlot:
          clearLastUsedSlot ? null : (lastUsedSlot ?? this.lastUsedSlot),
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'bonus_slots_state',
      'slots': slots
          .map(
            (slot) => slot.map((card) => card.toMap()).toList(growable: false),
          )
          .toList(growable: false),
      'openSlotsCount': openSlotsCount,
      if (lastUsedSlot case final value?) 'lastUsedSlot': value,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<BonusSlotsState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'bonus_slots_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final slotsRaw = map['slots'];
    final openSlotsCount = map['openSlotsCount'];
    final lastUsedSlot = map['lastUsedSlot'];
    if (openSlotsCount is! int ||
        (lastUsedSlot != null && lastUsedSlot is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsState payload.',
        ),
      );
    }

    final slots = <List<Card>>[
      <Card>[],
      <Card>[],
      <Card>[],
    ];
    if (slotsRaw != null) {
      if (slotsRaw is! List<dynamic> || slotsRaw.length != 3) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Bonus slots must be a list of exactly 3 slots.',
          ),
        );
      }
      for (var slotIndex = 0; slotIndex < slotsRaw.length; slotIndex++) {
        final slotRaw = slotsRaw[slotIndex];
        if (slotRaw is! List<dynamic>) {
          return const DecodeResult.failure(
            DecodeFailure(
              code: DecodeFailureCode.invalidPayload,
              message: 'Each bonus slot must be a list.',
            ),
          );
        }
        final slotCards = <Card>[];
        for (final rawCard in slotRaw) {
          if (rawCard is! Map<String, dynamic>) {
            return const DecodeResult.failure(
              DecodeFailure(
                code: DecodeFailureCode.invalidPayload,
                message: 'Bonus slot cards must be maps.',
              ),
            );
          }
          final cardResult = Card.tryFromMap(rawCard);
          if (!cardResult.isSuccess) {
            return DecodeResult.failure(cardResult.error!);
          }
          slotCards.add(cardResult.value!);
        }
        slots[slotIndex] = List<Card>.unmodifiable(slotCards);
      }
    }
    return DecodeResult.success(
      BonusSlotsState(
        slots: List<List<Card>>.unmodifiable(slots),
        openSlotsCount: openSlotsCount,
        lastUsedSlot: lastUsedSlot as int?,
      ),
    );
  }
}

/// Deterministic hint selection strategy.
enum HintSelectionStrategy {
  firstPlayableByIndex,
}

/// Configurable hint behavior.
final class HintConfig {
  /// Creates a hint config.
  const HintConfig({
    this.enabled = true,
    this.selectionStrategy = HintSelectionStrategy.firstPlayableByIndex,
  });

  /// Whether hints are enabled.
  final bool enabled;

  /// Strategy for selecting a single hint from playable moves.
  final HintSelectionStrategy selectionStrategy;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'hint_config',
      'enabled': enabled,
      'selectionStrategy': selectionStrategy.name,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<HintConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'hint_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final selectionName = map['selectionStrategy'];
    if (enabled is! bool || selectionName is! String) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid HintConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        HintConfig(
          enabled: enabled,
          selectionStrategy: HintSelectionStrategy.values.byName(selectionName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid HintConfig payload: $error',
        ),
      );
    }
  }
}

/// Configurable scoring values for match/session-level aggregation.
