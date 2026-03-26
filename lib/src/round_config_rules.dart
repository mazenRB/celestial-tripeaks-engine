part of '../tripeaks_engine.dart';

/// Configurable round mechanics rules.
final class RoundRulesConfig {
  /// Creates a round rules config.
  const RoundRulesConfig({
    this.aceKingWrapAround = true,
    this.startStockSize = 21,
    this.stockDecreaseEveryRounds = 2,
    this.minStockSize = 12,
  })  : assert(startStockSize >= 0, 'startStockSize must be >= 0.'),
        assert(
          stockDecreaseEveryRounds >= 1,
          'stockDecreaseEveryRounds must be >= 1.',
        ),
        assert(minStockSize >= 0, 'minStockSize must be >= 0.'),
        assert(
          startStockSize >= minStockSize,
          'startStockSize must be >= minStockSize.',
        );

  /// Whether ace and king are treated as adjacent.
  ///
  /// Set this to `true` for easy/wrap modes.
  final bool aceKingWrapAround;

  /// Initial stock size before round-based decreases.
  final int startStockSize;

  /// Number of rounds between each stock size decrease.
  final int stockDecreaseEveryRounds;

  /// Minimum stock size after all decreases.
  final int minStockSize;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_rules_config',
      'aceKingWrapAround': aceKingWrapAround,
      'startStockSize': startStockSize,
      'stockDecreaseEveryRounds': stockDecreaseEveryRounds,
      'minStockSize': minStockSize,
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
    final startStockSize = map['startStockSize'] ?? 21;
    final stockDecreaseEveryRounds = map['stockDecreaseEveryRounds'] ?? 2;
    final minStockSize = map['minStockSize'] ?? 12;
    if (startStockSize is! int ||
        stockDecreaseEveryRounds is! int ||
        minStockSize is! int ||
        startStockSize < 0 ||
        stockDecreaseEveryRounds < 1 ||
        minStockSize < 0 ||
        startStockSize < minStockSize) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundRulesConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      RoundRulesConfig(
        aceKingWrapAround: wrap,
        startStockSize: startStockSize,
        stockDecreaseEveryRounds: stockDecreaseEveryRounds,
        minStockSize: minStockSize,
      ),
    );
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
