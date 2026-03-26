part of '../tripeaks_engine.dart';

/// Streak tracking state for one round.
final class StreakState {
  /// Creates a streak state snapshot.
  const StreakState({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastActionTick,
  });

  /// Initial streak state at round start.
  static const StreakState initial = StreakState(
    currentStreak: 0,
    bestStreak: 0,
    lastActionTick: null,
  );

  /// Current active streak count.
  final int currentStreak;

  /// Best streak reached so far in this round.
  final int bestStreak;

  /// Last logical tick where a tableau-to-waste success happened.
  final int? lastActionTick;

  /// Returns a copy with optional changes.
  StreakState copyWith({
    int? currentStreak,
    int? bestStreak,
    int? lastActionTick,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastActionTick: lastActionTick ?? this.lastActionTick,
    );
  }

  /// Serializes streak state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'streak_state',
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      if (lastActionTick case final value?) 'lastActionTick': value,
    };
  }

  /// Decodes streak state from map without throwing.
  static DecodeResult<StreakState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'streak_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final currentStreak = map['currentStreak'];
    final bestStreak = map['bestStreak'];
    final lastActionTick = map['lastActionTick'];
    if (currentStreak is! int ||
        bestStreak is! int ||
        (lastActionTick != null && lastActionTick is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StreakState payload.',
        ),
      );
    }
    return DecodeResult.success(
      StreakState(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        lastActionTick: lastActionTick as int?,
      ),
    );
  }
}
