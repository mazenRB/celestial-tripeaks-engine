part of '../tripeaks_engine.dart';

/// Configurable scoring values for round actions.
final class ScoreConfig {
  /// Creates a scoring config.
  const ScoreConfig({
    this.pointsTableauToWaste = 5,
    this.pointsDrawFromStock = 0,
    this.penaltyInvalidAction = 0,
    this.allowNegativeTotalScore = true,
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

  /// Base points for a successful tableau removal onto the active playable pile.
  ///
  /// In normal play this means the waste pile. When bonus slots are open, the
  /// move may target one of those piles instead.
  final int pointsTableauToWaste;

  /// Points added for a stock draw action.
  final int pointsDrawFromStock;

  /// Delta applied for invalid actions.
  ///
  /// This can be negative to represent penalties.
  final int penaltyInvalidAction;

  /// Whether total score may go below zero.
  final bool allowNegativeTotalScore;

  /// Points awarded once when a peak is fully cleared.
  final int pointsPeakCleared;

  /// Bonus points awarded per remaining stock card when a round is won.
  final int pointsPerRemainingStockCardOnWin;

  /// Selects which multiplier system is active for scoring.
  ///
  /// This affects only tableau-base scoring, not draw scoring or other bonuses.
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
      'allowNegativeTotalScore': allowNegativeTotalScore,
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
    final allowNegativeTotalScore = map['allowNegativeTotalScore'];
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
        (allowNegativeTotalScore != null && allowNegativeTotalScore is! bool) ||
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
        allowNegativeTotalScore: allowNegativeTotalScore as bool? ?? true,
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
