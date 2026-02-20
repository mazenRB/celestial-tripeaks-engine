part of '../tripeaks_engine.dart';

/// Configurable scoring values for round actions.
final class ScoreConfig {
  /// Creates a scoring config.
  const ScoreConfig({
    this.pointsTableauToWaste = 5,
    this.pointsDrawFromStock = 0,
    this.penaltyInvalidAction = 0,
  });

  /// Points added when a tableau card is moved to waste.
  final int pointsTableauToWaste;

  /// Points added when drawing one card from stock.
  final int pointsDrawFromStock;

  /// Delta applied for invalid actions.
  ///
  /// This can be negative to represent penalties.
  final int penaltyInvalidAction;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_config',
      'pointsTableauToWaste': pointsTableauToWaste,
      'pointsDrawFromStock': pointsDrawFromStock,
      'penaltyInvalidAction': penaltyInvalidAction,
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
    if (a is! int || b is! int || c is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      ScoreConfig(
        pointsTableauToWaste: a,
        pointsDrawFromStock: b,
        penaltyInvalidAction: c,
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
  });

  /// Initial score state at round start.
  static const ScoreState initial = ScoreState(
    totalScore: 0,
    movesCount: 0,
    lastDelta: 0,
  );

  /// Total accumulated score for the round.
  final int totalScore;

  /// Count of scoring applications processed in this round.
  final int movesCount;

  /// Last applied score delta.
  final int lastDelta;

  /// Returns the next score state after applying [delta].
  ScoreState applyDelta(int delta) {
    return ScoreState(
      totalScore: totalScore + delta,
      movesCount: movesCount + 1,
      lastDelta: delta,
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
    return DecodeResult.success(
      ScoreState(
        totalScore: totalScore,
        movesCount: movesCount,
        lastDelta: lastDelta,
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
  const RoundRulesConfig({this.aceKingWrapAround = false});

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
    this.resetOnInvalidAction = false,
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
