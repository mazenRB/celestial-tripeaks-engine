part of '../tripeaks_engine.dart';

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
