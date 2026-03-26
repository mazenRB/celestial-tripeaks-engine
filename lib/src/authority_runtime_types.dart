part of '../tripeaks_engine.dart';

/// Host-provided context for one authority apply attempt.
final class AuthorityRequestContext {
  /// Creates request context.
  const AuthorityRequestContext({
    required this.subjectId,
    required this.playerId,
  });

  /// Authenticated identity from host auth boundary.
  final String subjectId;

  /// Server-resolved player id authorized for this match.
  final String playerId;
}

/// In-memory runtime state owned by [AuthorityRuntime].
final class AuthorityRuntimeState {
  /// Creates runtime state.
  const AuthorityRuntimeState({
    required this.matchState,
    required this.recentClientEventIdsByPlayer,
    required this.lastAcceptedClientSeqByPlayer,
    required this.idCapacityPerPlayer,
  });

  /// Creates baseline runtime state with authoritative sequence at 0.
  factory AuthorityRuntimeState.newBaseline({
    required MatchState matchState,
    required int idCapacityPerPlayer,
  }) {
    return AuthorityRuntimeState(
      matchState: matchState,
      recentClientEventIdsByPlayer: const <String, List<String>>{},
      lastAcceptedClientSeqByPlayer: const <String, int>{},
      idCapacityPerPlayer: idCapacityPerPlayer,
    );
  }

  /// Authoritative match state.
  final MatchState matchState;

  /// Recent accepted client event IDs by player.
  final Map<String, List<String>> recentClientEventIdsByPlayer;

  /// Last accepted client sequence by player.
  final Map<String, int> lastAcceptedClientSeqByPlayer;

  /// Per-player ring capacity.
  final int idCapacityPerPlayer;

  AuthorityRuntimeState _copyWith({
    MatchState? matchState,
    Map<String, List<String>>? recentClientEventIdsByPlayer,
    Map<String, int>? lastAcceptedClientSeqByPlayer,
  }) {
    return AuthorityRuntimeState(
      matchState: matchState ?? this.matchState,
      recentClientEventIdsByPlayer: Map<String, List<String>>.unmodifiable(
        (recentClientEventIdsByPlayer ?? this.recentClientEventIdsByPlayer).map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      ),
      lastAcceptedClientSeqByPlayer: Map<String, int>.unmodifiable(
        lastAcceptedClientSeqByPlayer ?? this.lastAcceptedClientSeqByPlayer,
      ),
      idCapacityPerPlayer: idCapacityPerPlayer,
    );
  }
}

/// Runtime apply result with duplicate and resync hints.
final class AuthorityApplyResult {
  /// Creates authority runtime apply result.
  const AuthorityApplyResult({
    required this.status,
    required this.state,
    required this.authoritativeSequence,
    this.failure,
    this.rejectReason,
    this.lastAcceptedClientSeq,
    this.mustFullyResync = false,
  });

  /// Outcome status.
  final ServerApplyStatus status;

  /// Updated runtime state.
  final AuthorityRuntimeState state;

  /// Current authoritative sequence after the attempt.
  final int authoritativeSequence;

  /// Typed failure details for rejected outcomes.
  final AuthorityApplyFailure? failure;

  /// Reject reason mapped from server rules when available.
  final ServerRejectReason? rejectReason;

  /// Last accepted client sequence for this player, when known.
  final int? lastAcceptedClientSeq;

  /// Whether client should perform full resync.
  final bool mustFullyResync;

  /// Whether the event was accepted.
  bool get accepted => status == ServerApplyStatus.accepted;

  /// Whether the event was duplicate and ignored.
  bool get duplicateIgnored => status == ServerApplyStatus.duplicateIgnored;

  /// Whether the result is rejected.
  bool get rejected => status == ServerApplyStatus.rejected;
}

/// Runtime restore result.
final class AuthorityRestoreResult {
  /// Creates restore result.
  const AuthorityRestoreResult({
    required this.isSuccess,
    required this.state,
    required this.snapshotSeq,
    this.failure,
    this.usedSnapshotFallback = false,
  });

  /// Whether restore was successful.
  final bool isSuccess;

  /// Restored runtime state.
  final AuthorityRuntimeState state;

  /// Snapshot sequence used as replay starting boundary.
  final int snapshotSeq;

  /// Failure details when restore fails.
  final AuthorityRestoreFailure? failure;

  /// Whether invalid snapshot fallback was used.
  final bool usedSnapshotFallback;
}
