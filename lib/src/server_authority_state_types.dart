part of 'tripeaks_engine_internal.dart';

/// Full server-authoritative state wrapper.
final class ServerAuthorityState {
  /// Creates server authority state.
  const ServerAuthorityState({
    required this.matchState,
    required this.eventLog,
    required this.lastAcceptedClientSequenceByPlayer,
    required this.processedClientEventIdsByPlayer,
    required this.processedEventIdWindowSize,
  });

  /// Creates initial server authority state for a match.
  factory ServerAuthorityState.newAuthority({
    required MatchState matchState,
    int processedEventIdWindowSize = 256,
  }) {
    return ServerAuthorityState(
      matchState: matchState,
      eventLog: const <ServerEventRecord>[],
      lastAcceptedClientSequenceByPlayer: const <String, int>{},
      processedClientEventIdsByPlayer: const <String, List<String>>{},
      processedEventIdWindowSize: processedEventIdWindowSize,
    );
  }

  /// Authoritative match state.
  final MatchState matchState;

  /// Append-only processed server event log.
  final List<ServerEventRecord> eventLog;

  /// Last accepted per-player client sequence.
  final Map<String, int> lastAcceptedClientSequenceByPlayer;

  /// Bounded processed client event ids per player.
  final Map<String, List<String>> processedClientEventIdsByPlayer;

  /// Max tracked ids retained per player.
  final int processedEventIdWindowSize;

  ServerAuthorityState _copyWith({
    MatchState? matchState,
    List<ServerEventRecord>? eventLog,
    Map<String, int>? lastAcceptedClientSequenceByPlayer,
    Map<String, List<String>>? processedClientEventIdsByPlayer,
  }) {
    return ServerAuthorityState(
      matchState: matchState ?? this.matchState,
      eventLog: List<ServerEventRecord>.unmodifiable(eventLog ?? this.eventLog),
      lastAcceptedClientSequenceByPlayer: Map<String, int>.unmodifiable(
        lastAcceptedClientSequenceByPlayer ??
            this.lastAcceptedClientSequenceByPlayer,
      ),
      processedClientEventIdsByPlayer: Map<String, List<String>>.unmodifiable(
        (processedClientEventIdsByPlayer ??
                this.processedClientEventIdsByPlayer)
            .map((key, value) =>
                MapEntry(key, List<String>.unmodifiable(value))),
      ),
      processedEventIdWindowSize: processedEventIdWindowSize,
    );
  }
}

/// Result of one server-authoritative client event application.
final class ServerResult {
  /// Creates server apply result.
  const ServerResult({
    required this.status,
    required this.state,
    this.reason,
    this.authoritativeSequence,
  });

  /// Outcome status.
  final ServerApplyStatus status;

  /// Updated authority state.
  final ServerAuthorityState state;

  /// Typed reject reason when rejected.
  final ServerRejectReason? reason;

  /// Assigned authoritative sequence when accepted.
  final int? authoritativeSequence;

  /// Whether event was applied.
  bool get accepted => status == ServerApplyStatus.accepted;

  /// Whether result is non-error (accepted or duplicate ignored).
  bool get isSuccess => status != ServerApplyStatus.rejected;

  /// Whether event was duplicate and ignored.
  bool get duplicateIgnored => status == ServerApplyStatus.duplicateIgnored;
}
