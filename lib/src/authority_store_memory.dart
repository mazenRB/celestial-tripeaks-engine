part of 'tripeaks_engine_internal.dart';

/// In-memory reference store for authority runtime.
final class InMemoryAuthorityStore implements AuthorityStorePort {
  /// Creates an in-memory store.
  InMemoryAuthorityStore({
    this.shouldFailAppend,
    this.shouldFailSaveSnapshot,
  });

  /// Optional append failure hook for tests.
  final bool Function(String matchId, PersistedAuthorityEvent event)?
      shouldFailAppend;

  /// Optional snapshot-save failure hook for tests.
  final bool Function(String matchId, PersistedAuthoritySnapshot snapshot)?
      shouldFailSaveSnapshot;

  final Map<String, List<PersistedAuthorityEvent>> _eventsByMatch =
      <String, List<PersistedAuthorityEvent>>{};
  final Map<String, PersistedAuthoritySnapshot> _snapshotByMatch =
      <String, PersistedAuthoritySnapshot>{};

  @override
  Future<void> appendAcceptedEvent(
    String matchId,
    PersistedAuthorityEvent event,
  ) async {
    if (shouldFailAppend?.call(matchId, event) ?? false) {
      throw StateError('appendAcceptedEvent failed by test hook.');
    }
    final list = _eventsByMatch.putIfAbsent(
      matchId,
      () => <PersistedAuthorityEvent>[],
    );
    list.add(event);
  }

  @override
  Future<List<PersistedAuthorityEvent>> loadAcceptedEventsAfter(
    String matchId,
    int seqExclusive,
  ) async {
    final list = _eventsByMatch[matchId] ?? const <PersistedAuthorityEvent>[];
    return list
        .where((event) => event.authoritativeSequence > seqExclusive)
        .toList(growable: false);
  }

  @override
  Future<void> saveSnapshot(
    String matchId,
    PersistedAuthoritySnapshot snapshot,
  ) async {
    if (shouldFailSaveSnapshot?.call(matchId, snapshot) ?? false) {
      throw StateError('saveSnapshot failed by test hook.');
    }
    _snapshotByMatch[matchId] = snapshot;
  }

  @override
  Future<PersistedAuthoritySnapshot?> loadLatestSnapshot(String matchId) async {
    return _snapshotByMatch[matchId];
  }

  /// Test helper to seed accepted events.
  void seedAcceptedEvents(
    String matchId,
    List<PersistedAuthorityEvent> events,
  ) {
    _eventsByMatch[matchId] = List<PersistedAuthorityEvent>.from(events);
  }

  /// Test helper to seed snapshot.
  void seedSnapshot(String matchId, PersistedAuthoritySnapshot snapshot) {
    _snapshotByMatch[matchId] = snapshot;
  }

  /// Test helper to inspect accepted events.
  List<PersistedAuthorityEvent> acceptedEvents(String matchId) {
    return List<PersistedAuthorityEvent>.from(
      _eventsByMatch[matchId] ?? const <PersistedAuthorityEvent>[],
    );
  }
}
