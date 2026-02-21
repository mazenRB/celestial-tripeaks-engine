part of '../tripeaks_engine.dart';

/// Store abstraction for accepted events and snapshots.
abstract interface class AuthorityStorePort {
  /// Appends one accepted authoritative event.
  Future<void> appendAcceptedEvent(
    String matchId,
    PersistedAuthorityEvent event,
  );

  /// Loads accepted events with sequence strictly greater than [seqExclusive].
  Future<List<PersistedAuthorityEvent>> loadAcceptedEventsAfter(
    String matchId,
    int seqExclusive,
  );

  /// Persists the latest snapshot for [matchId].
  Future<void> saveSnapshot(
    String matchId,
    PersistedAuthoritySnapshot snapshot,
  );

  /// Loads the most recent snapshot for [matchId].
  Future<PersistedAuthoritySnapshot?> loadLatestSnapshot(String matchId);
}
