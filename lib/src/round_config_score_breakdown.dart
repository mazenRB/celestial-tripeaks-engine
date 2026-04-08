part of '../tripeaks_engine.dart';

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

  /// Returns a copy with optional changes.
  ScoreDeltaBreakdown copyWith({
    int? tableauBasePoints,
    int? multiplierExtraPoints,
    int? peakBonusPoints,
    int? drawPoints,
    int? invalidPenaltyPoints,
    int? endRoundRemainingStockBonusPoints,
    int? appliedMultiplier,
    int? totalDelta,
  }) {
    return ScoreDeltaBreakdown(
      tableauBasePoints: tableauBasePoints ?? this.tableauBasePoints,
      multiplierExtraPoints:
          multiplierExtraPoints ?? this.multiplierExtraPoints,
      peakBonusPoints: peakBonusPoints ?? this.peakBonusPoints,
      drawPoints: drawPoints ?? this.drawPoints,
      invalidPenaltyPoints: invalidPenaltyPoints ?? this.invalidPenaltyPoints,
      endRoundRemainingStockBonusPoints: endRoundRemainingStockBonusPoints ??
          this.endRoundRemainingStockBonusPoints,
      appliedMultiplier: appliedMultiplier ?? this.appliedMultiplier,
      totalDelta: totalDelta ?? this.totalDelta,
    );
  }

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
