import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

/// One player's private session and replay inside a shared match.
final class MatchPlayerState {
  /// Creates a player's match state.
  const MatchPlayerState({
    required this.playerId,
    required this.session,
    required this.replay,
    this.withdrawn = false,
  });

  /// Stable participant identifier from the match roster.
  final String playerId;

  /// This participant's independent game session.
  final TriPeaksSessionState session;

  /// Replay of this participant's deterministic session actions.
  final ReplaySession replay;

  /// Whether this participant withdrew from an asynchronous match.
  final bool withdrawn;

  /// Serializes this participant and their replay.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'type': 'multiplayer_match_player',
        'playerId': playerId,
        'session': session.toMap(),
        'replay': replay.toMap(),
        'withdrawn': withdrawn,
      };

  /// Decodes a player state.
  static DecodeResult<MatchPlayerState> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != 1) {
      return const DecodeResult<MatchPlayerState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported multiplayer player schema.',
        ),
      );
    }
    if (map['type'] != 'multiplayer_match_player') {
      return const DecodeResult<MatchPlayerState>.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown multiplayer player type.',
        ),
      );
    }
    try {
      final sessionMap = map['session'] as Map<String, dynamic>;
      final replayMap = map['replay'] as Map<String, dynamic>;
      final session = TriPeaksSessionState.tryFromMap(sessionMap);
      if (!session.isSuccess) return DecodeResult.failure(session.error!);
      final replay = ReplaySession.tryFromMap(replayMap);
      if (!replay.isSuccess) return DecodeResult.failure(replay.error!);
      return DecodeResult.success(
        MatchPlayerState(
          playerId: map['playerId'] as String,
          session: session.value!,
          replay: replay.value!,
          withdrawn: map['withdrawn'] as bool? ?? false,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid multiplayer player payload: $error',
        ),
      );
    }
  }
}

/// Deterministic room-independent multiplayer match state.
