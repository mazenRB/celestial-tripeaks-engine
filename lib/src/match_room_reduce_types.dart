part of '../tripeaks_engine.dart';

/// Match reducer failure code.
enum MatchReduceFailureCode {
  matchFull,
  playerAlreadyJoined,
  playerNotFound,
  matchAlreadyStarted,
  matchNotStarted,
  matchAlreadyFinished,
  playerNotActive,
}

/// Typed match reducer failure.
final class MatchReduceFailure {
  /// Creates match reducer failure.
  const MatchReduceFailure({
    required this.code,
    required this.message,
  });

  /// Machine-friendly code.
  final MatchReduceFailureCode code;

  /// Human-friendly message.
  final String message;
}

/// Result from match reducer.
final class MatchReduceResult {
  /// Creates match reducer result.
  const MatchReduceResult({
    required this.state,
    this.failure,
  });

  /// Resulting state.
  final MatchState state;

  /// Failure details for rejected event.
  final MatchReduceFailure? failure;

  /// Whether event was accepted.
  bool get isSuccess => failure == null;
}
