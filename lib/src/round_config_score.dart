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
    this.roundBasePointsGrowthBps = 0,
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

  /// Compounding growth applied to tableau base points per round (bps).
  final int roundBasePointsGrowthBps;

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
      'roundBasePointsGrowthBps': roundBasePointsGrowthBps,
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
    final roundBasePointsGrowthBps = map['roundBasePointsGrowthBps'];
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
        (roundBasePointsGrowthBps != null &&
            roundBasePointsGrowthBps is! int) ||
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
        roundBasePointsGrowthBps: roundBasePointsGrowthBps as int? ?? 0,
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
