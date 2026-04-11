part of 'tripeaks_engine_internal.dart';

/// Typed apply failure codes for authority runtime.
enum AuthorityApplyFailureCode {
  invalidContext,
  invalidClientEvent,
  playerNotInMatch,
  outOfOrderClientSequence,
  reducerRejected,
  durabilityFailure,
}

/// Typed apply failure payload.
final class AuthorityApplyFailure {
  /// Creates apply failure.
  const AuthorityApplyFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly failure code.
  final AuthorityApplyFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Typed restore failure codes for authority runtime.
enum AuthorityRestoreFailureCode {
  storeReadFailed,
  storeWriteFailed,
  snapshotInvalid,
  matchIdMismatch,
  invalidPersistedEvent,
  sequenceGap,
  reducerReplayFailed,
}

/// Typed restore failure payload.
final class AuthorityRestoreFailure {
  /// Creates restore failure.
  const AuthorityRestoreFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly failure code.
  final AuthorityRestoreFailureCode code;

  /// Human-friendly message.
  final String message;
}
