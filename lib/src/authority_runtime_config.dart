part of '../tripeaks_engine.dart';

/// Runtime configuration for authority orchestration.
final class AuthorityRuntimeConfig {
  /// Creates runtime configuration.
  const AuthorityRuntimeConfig({
    this.snapshotEveryAccepted = 100,
    this.processedClientEventIdsCapacityPerPlayer = 1000,
  })  : assert(snapshotEveryAccepted > 0),
        assert(processedClientEventIdsCapacityPerPlayer > 0);

  /// Save a full snapshot after every N accepted events.
  final int snapshotEveryAccepted;

  /// Max recent event IDs retained per player for duplicate suppression.
  final int processedClientEventIdsCapacityPerPlayer;
}
