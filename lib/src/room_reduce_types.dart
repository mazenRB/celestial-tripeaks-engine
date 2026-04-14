part of 'tripeaks_engine_internal.dart';

/// Room reducer failure codes.
enum RoomReduceFailureCode {
  roomClosed,
  roomFull,
  memberAlreadyJoined,
  memberNotFound,
  memberNotJoined,
  hostRequired,
  invalidStartMembers,
  matchAlreadyInProgress,
  matchNotInProgress,
  activeMatchIdMismatch,
}

/// Typed room reducer failure.
final class RoomReduceFailure {
  /// Creates a room reducer failure.
  const RoomReduceFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly code.
  final RoomReduceFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Result from one room reducer step.
final class RoomReduceResult {
  /// Creates a room reducer result.
  const RoomReduceResult({
    required this.state,
    this.failure,
    this.bootstrap,
  });

  /// Resulting room state.
  final RoomState state;

  /// Failure details for rejected event.
  final RoomReduceFailure? failure;

  /// Canonical bootstrap payload when a match start is accepted.
  final MatchBootstrap? bootstrap;

  /// Whether the event was accepted.
  bool get isSuccess => failure == null;
}
