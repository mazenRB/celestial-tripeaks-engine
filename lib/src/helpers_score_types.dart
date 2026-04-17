part of 'tripeaks_engine_internal.dart';

/// Config for additive independent-run aggregation outside core mechanics.
final class CompetitionScoreConfig {
  /// Creates a competition score config.
  const CompetitionScoreConfig({
    this.completionBonus = 0,
    this.placementAdjustments = const <int, int>{},
  });

  /// Bonus applied to a completed run.
  final int completionBonus;

  /// Optional points by final rank.
  final Map<int, int> placementAdjustments;
}

/// Error codes for invalid competition score events.
enum CompetitionScoreErrorCode {
  completionBonusAlreadyAwarded,
}

/// Typed competition score error details.
final class CompetitionScoreError {
  /// Creates a competition score error.
  const CompetitionScoreError({
    required this.code,
    required this.message,
  });

  /// Machine-friendly error code.
  final CompetitionScoreErrorCode code;

  /// Human-friendly error message.
  final String message;
}

/// Result from a non-throwing competition score reducer operation.
final class CompetitionScoreReduceResult {
  /// Creates a competition score reducer result.
  const CompetitionScoreReduceResult({
    required this.state,
    this.error,
  });

  /// Resulting score state.
  final CompetitionScoreState state;

  /// Error details for invalid events.
  final CompetitionScoreError? error;

  /// Whether reduction succeeded.
  bool get isSuccess => error == null;
}

/// Base type for ordered competition-score events.
sealed class CompetitionScoreEvent {
  const CompetitionScoreEvent();
}

/// Event that commits one run score for an entry.
final class RunScoreRecorded extends CompetitionScoreEvent {
  /// Creates a run score event.
  const RunScoreRecorded({
    required this.entryId,
    required this.runScore,
  });

  /// Neutral entry identifier.
  final String entryId;

  /// Run score to add.
  final int runScore;
}

/// Explicit event applying a completion bonus.
final class BonusApplied extends CompetitionScoreEvent {
  /// Creates a bonus application event.
  const BonusApplied({required this.entryId});

  /// Neutral entry identifier.
  final String entryId;
}

/// Explicit event applying a placement adjustment.
final class PlacementAdjustmentApplied extends CompetitionScoreEvent {
  /// Creates a placement adjustment event.
  const PlacementAdjustmentApplied({
    required this.entryId,
    required this.rank,
  });

  /// Neutral entry identifier.
  final String entryId;

  /// Final rank.
  final int rank;
}

/// Immutable helper state for additive scoring across completed runs.
final class CompetitionScoreState {
  /// Creates an empty competition score state.
  const CompetitionScoreState({
    this.config = const CompetitionScoreConfig(),
    this.runScoresByEntry = const <String, int>{},
    this.bonusesByEntry = const <String, int>{},
    this.placementAdjustmentsByEntry = const <String, int>{},
    this.completionBonusAwardedTo = const <String>{},
    this.processedEventsCount = 0,
  });

  /// Helper score config.
  final CompetitionScoreConfig config;

  /// Base run scores by entry.
  final Map<String, int> runScoresByEntry;

  /// Bonus totals by entry.
  final Map<String, int> bonusesByEntry;

  /// Placement adjustment totals by entry.
  final Map<String, int> placementAdjustmentsByEntry;

  /// Entries that already received the one-time completion bonus.
  final Set<String> completionBonusAwardedTo;

  /// Number of processed helper events.
  final int processedEventsCount;

  /// Returns total score for [entryId].
  int totalFor(String entryId) {
    return (runScoresByEntry[entryId] ?? 0) +
        (bonusesByEntry[entryId] ?? 0) +
        (placementAdjustmentsByEntry[entryId] ?? 0);
  }

  /// Returns combined totals by entry.
  Map<String, int> get totalScoresByEntry {
    final entryIds = <String>{
      ...runScoresByEntry.keys,
      ...bonusesByEntry.keys,
      ...placementAdjustmentsByEntry.keys,
    };
    final totals = <String, int>{};
    for (final entryId in entryIds) {
      totals[entryId] = totalFor(entryId);
    }
    return Map<String, int>.unmodifiable(totals);
  }

  CompetitionScoreState _copyWith({
    Map<String, int>? runScoresByEntry,
    Map<String, int>? bonusesByEntry,
    Map<String, int>? placementAdjustmentsByEntry,
    Set<String>? completionBonusAwardedTo,
    int? processedEventsCount,
  }) {
    return CompetitionScoreState(
      config: config,
      runScoresByEntry: Map<String, int>.unmodifiable(
          runScoresByEntry ?? this.runScoresByEntry),
      bonusesByEntry:
          Map<String, int>.unmodifiable(bonusesByEntry ?? this.bonusesByEntry),
      placementAdjustmentsByEntry: Map<String, int>.unmodifiable(
        placementAdjustmentsByEntry ?? this.placementAdjustmentsByEntry,
      ),
      completionBonusAwardedTo: Set<String>.unmodifiable(
        completionBonusAwardedTo ?? this.completionBonusAwardedTo,
      ),
      processedEventsCount: processedEventsCount ?? this.processedEventsCount,
    );
  }
}
