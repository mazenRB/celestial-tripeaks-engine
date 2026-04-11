part of 'tripeaks_engine_internal.dart';

AuthorityRestoreFailure? _authorityValidateSnapshot(
  String matchId,
  PersistedAuthoritySnapshot snapshot,
) {
  if (snapshot.matchId != matchId) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.matchIdMismatch,
      message: 'Snapshot matchId does not match restore target.',
    );
  }
  if (snapshot.schemaVersion != _serializationSchemaV1) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.snapshotInvalid,
      message: 'Snapshot schemaVersion is unsupported.',
    );
  }
  if (snapshot.matchState.config.matchId != matchId ||
      snapshot.matchState.authoritativeSequence !=
          snapshot.authoritativeSequence) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.snapshotInvalid,
      message: 'Snapshot payload is inconsistent.',
    );
  }
  if (snapshot.engineVersion != snapshot.matchState.engineVersion) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.snapshotInvalid,
      message: 'Snapshot engineVersion mismatch.',
    );
  }
  return null;
}

AuthorityRestoreFailure? _authorityValidatePersistedEvent(
  PersistedAuthorityEvent event, {
  required int expectedSequence,
  required String matchId,
}) {
  if (event.schemaVersion != _serializationSchemaV1) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.invalidPersistedEvent,
      message: 'Persisted event schemaVersion is unsupported.',
    );
  }
  if (event.matchId != matchId ||
      event.clientEvent.matchId != matchId ||
      event.serverRecord.clientEvent.matchId != matchId) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.matchIdMismatch,
      message: 'Persisted event matchId mismatch.',
    );
  }
  if (event.authoritativeSequence != expectedSequence) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.sequenceGap,
      message: 'Persisted accepted events must be strictly contiguous.',
    );
  }
  if (!event.serverRecord.accepted ||
      event.serverRecord.authoritativeSequence != event.authoritativeSequence ||
      event.serverRecord.clientEvent.clientEventId != event.clientEventId ||
      event.serverRecord.clientEvent.clientSeq != event.clientSeq ||
      event.serverRecord.clientEvent.playerId != event.playerId) {
    return const AuthorityRestoreFailure(
      code: AuthorityRestoreFailureCode.invalidPersistedEvent,
      message: 'Persisted accepted event metadata is inconsistent.',
    );
  }
  return null;
}

Map<String, List<String>> _authorityCloneRecentIds(
  Map<String, List<String>> input,
  int capacity,
) {
  return input.map(
    (key, value) => MapEntry(key, _authorityTrimFifo(value, capacity)),
  );
}

List<String> _authorityTrimFifo(List<String> values, int capacity) {
  if (values.length <= capacity) {
    return List<String>.from(values);
  }
  return values.sublist(values.length - capacity);
}
