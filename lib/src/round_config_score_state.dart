part of '../tripeaks_engine.dart';

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
