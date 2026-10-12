import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

import 'multiplayer_state.dart';

/// A deterministic action applied to multiplayer state.
sealed class MatchEvent {
  /// Creates a match event.
  const MatchEvent();

  /// Serializes this event with a schema version.
  Map<String, dynamic> toMap();

  /// Decodes a supported match event.
  static DecodeResult<MatchEvent> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<MatchEvent>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported multiplayer event schema.',
        ),
      );
    }
    try {
      switch (map['type']) {
        case 'submit_match_action':
          final action = ReplayActionDto.tryFromMap(
            map['action'] as Map<String, dynamic>,
          );
          if (!action.isSuccess) return DecodeResult.failure(action.error!);
          return DecodeResult.success(
            SubmitMatchActionEvent(
              playerId: map['playerId'] as String,
              action: action.value!.toSessionAction(),
            ),
          );
        case 'vote_to_skip_live_intermission':
          return DecodeResult.success(
            VoteToSkipLiveIntermissionEvent(
                playerId: map['playerId'] as String),
          );
        case 'advance_live_intermission':
          return DecodeResult.success(
            AdvanceLiveIntermissionEvent(
              elapsedSeconds: map['elapsedSeconds'] as int,
              deadlineToken: map['deadlineToken'] as int,
            ),
          );
        case 'advance_async_deadline':
          return DecodeResult.success(
            AdvanceAsyncDeadlineEvent(
              elapsedSeconds: map['elapsedSeconds'] as int,
              deadlineToken: map['deadlineToken'] as int,
            ),
          );
        case 'withdraw_from_async_match':
          return DecodeResult.success(
            WithdrawFromAsyncMatchEvent(playerId: map['playerId'] as String),
          );
        default:
          return const DecodeResult<MatchEvent>.failure(
            DecodeFailure(
              code: DecodeFailureCode.unknownType,
              message: 'Unknown multiplayer event type.',
            ),
          );
      }
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid multiplayer event: $error',
        ),
      );
    }
  }
}

/// Submits one engine action for one participant.
final class SubmitMatchActionEvent extends MatchEvent {
  /// Creates a player action event.
  const SubmitMatchActionEvent({required this.playerId, required this.action});

  /// Participant whose independent session receives the action.
  final String playerId;

  /// Session action applied to that participant only.
  final TriPeaksSessionAction action;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'submit_match_action',
        'playerId': playerId,
        'action': ReplayActionDto.fromSessionAction(action).toMap(),
      };
}

/// Votes to skip the active live intermission.
final class VoteToSkipLiveIntermissionEvent extends MatchEvent {
  /// Creates a skip vote.
  const VoteToSkipLiveIntermissionEvent({required this.playerId});

  /// Participant casting the vote.
  final String playerId;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'vote_to_skip_live_intermission',
        'playerId': playerId,
      };
}

/// Advances the live intermission using host-reported elapsed time.
final class AdvanceLiveIntermissionEvent extends MatchEvent {
  /// Creates a live intermission timer action.
  const AdvanceLiveIntermissionEvent({
    required this.elapsedSeconds,
    required this.deadlineToken,
  });

  /// Whole seconds elapsed since the previous timer update.
  final int elapsedSeconds;

  /// Token that prevents stale timer updates.
  final int deadlineToken;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'advance_live_intermission',
        'elapsedSeconds': elapsedSeconds,
        'deadlineToken': deadlineToken,
      };
}

/// Advances the asynchronous match deadline using host-reported time.
final class AdvanceAsyncDeadlineEvent extends MatchEvent {
  /// Creates an asynchronous deadline timer action.
  const AdvanceAsyncDeadlineEvent({
    required this.elapsedSeconds,
    required this.deadlineToken,
  });

  /// Whole seconds elapsed since the previous deadline update.
  final int elapsedSeconds;

  /// Token that prevents stale deadline updates.
  final int deadlineToken;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'advance_async_deadline',
        'elapsedSeconds': elapsedSeconds,
        'deadlineToken': deadlineToken,
      };
}

/// Ends an asynchronous match when a participant withdraws.
final class WithdrawFromAsyncMatchEvent extends MatchEvent {
  /// Creates a participant withdrawal event.
  const WithdrawFromAsyncMatchEvent({required this.playerId});

  /// Participant withdrawing from the match.
  final String playerId;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'withdraw_from_async_match',
        'playerId': playerId,
      };
}

/// Reasons a multiplayer event cannot be applied.
enum MatchReduceFailureCode {
  matchAlreadyFinished,
  playerNotFound,
  playerAlreadyFinished,
  wrongMatchMode,
  wrongMatchPhase,
  duplicateSkipVote,
  staleTimer,
  invalidElapsedSeconds,
  actionRejected,
}

/// A typed failure from a match reducer.
final class MatchReduceFailure {
  /// Creates a reducer failure.
  const MatchReduceFailure({required this.code, required this.message});

  /// Stable failure category.
  final MatchReduceFailureCode code;

  /// Human-readable diagnostic for an integrating application.
  final String message;
}

/// Result of reducing a multiplayer event.
final class MatchReduceResult {
  /// Creates a reducer result.
  const MatchReduceResult({required this.state, this.failure});

  /// Resulting state, unchanged when reduction fails.
  final MatchState state;

  /// Failure details, if the event was rejected.
  final MatchReduceFailure? failure;

  /// Whether the event was accepted.
  bool get isSuccess => failure == null;
}
