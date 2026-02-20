part of '../tripeaks_engine.dart';

/// Configurable scoring values for round actions.
final class ScoreConfig {
  /// Creates a scoring config.
  const ScoreConfig({
    this.pointsTableauToWaste = 5,
    this.pointsDrawFromStock = 0,
    this.penaltyInvalidAction = 0,
    this.pointsPeakCleared = 0,
  });

  /// Points added when a tableau card is moved to waste.
  final int pointsTableauToWaste;

  /// Points added when drawing one card from stock.
  final int pointsDrawFromStock;

  /// Delta applied for invalid actions.
  ///
  /// This can be negative to represent penalties.
  final int penaltyInvalidAction;

  /// Points awarded once when a peak is fully cleared.
  final int pointsPeakCleared;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_config',
      'pointsTableauToWaste': pointsTableauToWaste,
      'pointsDrawFromStock': pointsDrawFromStock,
      'penaltyInvalidAction': penaltyInvalidAction,
      'pointsPeakCleared': pointsPeakCleared,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<ScoreConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'score_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final a = map['pointsTableauToWaste'];
    final b = map['pointsDrawFromStock'];
    final c = map['penaltyInvalidAction'];
    final d = map['pointsPeakCleared'];
    if (a is! int || b is! int || c is! int || d is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      ScoreConfig(
        pointsTableauToWaste: a,
        pointsDrawFromStock: b,
        penaltyInvalidAction: c,
        pointsPeakCleared: d,
      ),
    );
  }
}

/// Scoring state for one round.
final class ScoreState {
  /// Creates a score state snapshot.
  const ScoreState({
    required this.totalScore,
    required this.movesCount,
    required this.lastDelta,
  });

  /// Initial score state at round start.
  static const ScoreState initial = ScoreState(
    totalScore: 0,
    movesCount: 0,
    lastDelta: 0,
  );

  /// Total accumulated score for the round.
  final int totalScore;

  /// Count of scoring applications processed in this round.
  final int movesCount;

  /// Last applied score delta.
  final int lastDelta;

  /// Returns the next score state after applying [delta].
  ScoreState applyDelta(int delta) {
    return ScoreState(
      totalScore: totalScore + delta,
      movesCount: movesCount + 1,
      lastDelta: delta,
    );
  }

  /// Serializes score state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'score_state',
      'totalScore': totalScore,
      'movesCount': movesCount,
      'lastDelta': lastDelta,
    };
  }

  /// Decodes score state from map without throwing.
  static DecodeResult<ScoreState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'score_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final totalScore = map['totalScore'];
    final movesCount = map['movesCount'];
    final lastDelta = map['lastDelta'];
    if (totalScore is! int || movesCount is! int || lastDelta is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid ScoreState payload.',
        ),
      );
    }
    return DecodeResult.success(
      ScoreState(
        totalScore: totalScore,
        movesCount: movesCount,
        lastDelta: lastDelta,
      ),
    );
  }
}

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

/// Configurable round mechanics rules.
final class RoundRulesConfig {
  /// Creates a round rules config.
  const RoundRulesConfig({this.aceKingWrapAround = true});

  /// Whether ace and king are treated as adjacent.
  ///
  /// Set this to `true` for easy/wrap modes.
  final bool aceKingWrapAround;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'round_rules_config',
      'aceKingWrapAround': aceKingWrapAround,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<RoundRulesConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'round_rules_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final wrap = map['aceKingWrapAround'];
    if (wrap is! bool) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid RoundRulesConfig payload.',
        ),
      );
    }
    return DecodeResult.success(RoundRulesConfig(aceKingWrapAround: wrap));
  }
}

/// Configurable undo behavior for a round.
final class UndoConfig {
  /// Creates an undo config.
  const UndoConfig({
    this.enabled = true,
    this.maxSteps = 10,
  }) : assert(maxSteps >= 0, 'maxSteps must be >= 0.');

  /// Whether undo is enabled.
  final bool enabled;

  /// Maximum number of snapshots retained for undo.
  final int maxSteps;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'undo_config',
      'enabled': enabled,
      'maxSteps': maxSteps,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<UndoConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'undo_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final maxSteps = map['maxSteps'];
    if (enabled is! bool || maxSteps is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid UndoConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
        UndoConfig(enabled: enabled, maxSteps: maxSteps));
  }
}

/// Configurable streak behavior for a round.
final class StreakConfig {
  /// Creates a streak config.
  const StreakConfig({
    this.enabled = true,
    this.resetOnDraw = true,
    this.resetOnInvalidAction = true,
    this.maxGapTicks,
  }) : assert(maxGapTicks == null || maxGapTicks >= 0);

  /// Whether streak tracking is enabled.
  final bool enabled;

  /// Whether streak resets on successful draw actions.
  final bool resetOnDraw;

  /// Whether streak resets when an action is invalid.
  final bool resetOnInvalidAction;

  /// Optional maximum allowed gap between streak actions.
  ///
  /// If set and `(tick - lastActionTick) > maxGapTicks`, the current streak
  /// resets before processing the incoming action.
  final int? maxGapTicks;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'streak_config',
      'enabled': enabled,
      'resetOnDraw': resetOnDraw,
      'resetOnInvalidAction': resetOnInvalidAction,
      if (maxGapTicks case final value?) 'maxGapTicks': value,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<StreakConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'streak_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final resetOnDraw = map['resetOnDraw'];
    final resetOnInvalidAction = map['resetOnInvalidAction'];
    final maxGapTicks = map['maxGapTicks'];
    if (enabled is! bool ||
        resetOnDraw is! bool ||
        resetOnInvalidAction is! bool ||
        (maxGapTicks != null && maxGapTicks is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StreakConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      StreakConfig(
        enabled: enabled,
        resetOnDraw: resetOnDraw,
        resetOnInvalidAction: resetOnInvalidAction,
        maxGapTicks: maxGapTicks as int?,
      ),
    );
  }
}

/// Configurable strike-timer behavior for streak expiry.
final class StrikeTimerConfig {
  /// Creates a strike-timer config.
  const StrikeTimerConfig({
    this.enabled = true,
    this.timeoutSeconds = 10,
  }) : assert(timeoutSeconds > 0, 'timeoutSeconds must be > 0.');

  /// Whether strike-timer expirations are enabled.
  final bool enabled;

  /// Timeout value in seconds used by orchestration layers.
  final int timeoutSeconds;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'strike_timer_config',
      'enabled': enabled,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<StrikeTimerConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'strike_timer_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final timeoutSeconds = map['timeoutSeconds'];
    if (enabled is! bool || timeoutSeconds is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        StrikeTimerConfig(
          enabled: enabled,
          timeoutSeconds: timeoutSeconds,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerConfig payload: $error',
        ),
      );
    }
  }
}

/// Runtime strike-timer state for one round.
final class StrikeTimerState {
  /// Creates strike-timer state.
  const StrikeTimerState({
    required this.isArmed,
    required this.deadlineToken,
  });

  /// Initial strike-timer state.
  static const StrikeTimerState initial = StrikeTimerState(
    isArmed: false,
    deadlineToken: 0,
  );

  /// Whether a strike timer is currently armed.
  final bool isArmed;

  /// Monotonic token used to validate expiry events.
  final int deadlineToken;

  /// Returns a copy with optional changes.
  StrikeTimerState copyWith({
    bool? isArmed,
    int? deadlineToken,
  }) {
    return StrikeTimerState(
      isArmed: isArmed ?? this.isArmed,
      deadlineToken: deadlineToken ?? this.deadlineToken,
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'strike_timer_state',
      'isArmed': isArmed,
      'deadlineToken': deadlineToken,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<StrikeTimerState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'strike_timer_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final isArmed = map['isArmed'];
    final deadlineToken = map['deadlineToken'];
    if (isArmed is! bool || deadlineToken is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid StrikeTimerState payload.',
        ),
      );
    }
    return DecodeResult.success(
      StrikeTimerState(
        isArmed: isArmed,
        deadlineToken: deadlineToken,
      ),
    );
  }
}

/// Configurable bonus-slot behavior linked to streak progression.
enum BonusSlotSpawnPolicy {
  joker,
  tierFixedRank,
}

/// Tier used when spawning deterministic anchor cards.
enum BonusSlotAnchorTier {
  low,
  high,
}

/// Configurable bonus-slot behavior linked to streak progression.
final class BonusSlotsConfig {
  /// Creates bonus-slots config.
  const BonusSlotsConfig({
    this.enabled = true,
    this.spawnPolicy = BonusSlotSpawnPolicy.tierFixedRank,
    this.defaultAnchorTierWhenUnknown = BonusSlotAnchorTier.low,
    this.lowTierAnchorRank = Rank.six,
    this.highTierAnchorRank = Rank.queen,
    this.jokerAcceptsAnyRank = true,
    this.jokerConsumedOnFirstUse = true,
    this.spawnOnOpenSlot2AtStreak = 3,
    this.spawnOnOpenSlot3AtStreak = 6,
    this.closeOnDraw = true,
    this.closeOnInvalidAction = true,
    this.maxSlots = 3,
  })  : assert(spawnOnOpenSlot2AtStreak >= 1),
        assert(spawnOnOpenSlot3AtStreak >= 1),
        assert(
          lowTierAnchorRank != Rank.ace &&
              lowTierAnchorRank != Rank.jack &&
              lowTierAnchorRank != Rank.queen &&
              lowTierAnchorRank != Rank.king,
        ),
        assert(
          highTierAnchorRank == Rank.ace ||
              highTierAnchorRank == Rank.jack ||
              highTierAnchorRank == Rank.queen ||
              highTierAnchorRank == Rank.king,
        ),
        assert(maxSlots == 3);

  /// Whether bonus slots logic is enabled.
  final bool enabled;

  /// Slot-open spawn behavior.
  final BonusSlotSpawnPolicy spawnPolicy;

  /// Default tier used when no successful tableau move exists yet.
  final BonusSlotAnchorTier defaultAnchorTierWhenUnknown;

  /// Fixed anchor rank for LOW tier.
  final Rank lowTierAnchorRank;

  /// Fixed anchor rank for HIGH tier.
  final Rank highTierAnchorRank;

  /// Whether joker anchors allow any rank to be placed.
  final bool jokerAcceptsAnyRank;

  /// Whether joker anchors are consumed when first used.
  final bool jokerConsumedOnFirstUse;

  /// Streak threshold that unlocks/spawns slot 2.
  final int spawnOnOpenSlot2AtStreak;

  /// Streak threshold that unlocks/spawns slot 3.
  final int spawnOnOpenSlot3AtStreak;

  /// Whether draw actions close unlocked bonus slots.
  final bool closeOnDraw;

  /// Whether invalid actions close unlocked bonus slots.
  final bool closeOnInvalidAction;

  /// Max supported slot count.
  ///
  /// Slot1 is always available.
  final int maxSlots;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'bonus_slots_config',
      'enabled': enabled,
      'spawnPolicy': spawnPolicy.name,
      'defaultAnchorTierWhenUnknown': defaultAnchorTierWhenUnknown.name,
      'lowTierAnchorRank': lowTierAnchorRank.name,
      'highTierAnchorRank': highTierAnchorRank.name,
      'jokerAcceptsAnyRank': jokerAcceptsAnyRank,
      'jokerConsumedOnFirstUse': jokerConsumedOnFirstUse,
      'spawnOnOpenSlot2AtStreak': spawnOnOpenSlot2AtStreak,
      'spawnOnOpenSlot3AtStreak': spawnOnOpenSlot3AtStreak,
      'closeOnDraw': closeOnDraw,
      'closeOnInvalidAction': closeOnInvalidAction,
      'maxSlots': maxSlots,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<BonusSlotsConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'bonus_slots_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final spawnPolicy = map['spawnPolicy'] ?? BonusSlotSpawnPolicy.joker.name;
    final defaultAnchorTierWhenUnknown =
        map['defaultAnchorTierWhenUnknown'] ?? BonusSlotAnchorTier.low.name;
    final lowTierAnchorRank = map['lowTierAnchorRank'] ?? Rank.six.name;
    final highTierAnchorRank = map['highTierAnchorRank'] ?? Rank.queen.name;
    final jokerAcceptsAnyRank = map['jokerAcceptsAnyRank'] ?? true;
    final jokerConsumedOnFirstUse = map['jokerConsumedOnFirstUse'] ?? true;
    final spawnOnOpenSlot2AtStreak =
        map['spawnOnOpenSlot2AtStreak'] ?? map['unlockAtStreakSlot2'];
    final spawnOnOpenSlot3AtStreak =
        map['spawnOnOpenSlot3AtStreak'] ?? map['unlockAtStreakSlot3'];
    final closeOnDraw = map['closeOnDraw'];
    final closeOnInvalidAction = map['closeOnInvalidAction'];
    final maxSlots = map['maxSlots'];
    if (enabled is! bool ||
        spawnPolicy is! String ||
        defaultAnchorTierWhenUnknown is! String ||
        lowTierAnchorRank is! String ||
        highTierAnchorRank is! String ||
        jokerAcceptsAnyRank is! bool ||
        jokerConsumedOnFirstUse is! bool ||
        spawnOnOpenSlot2AtStreak is! int ||
        spawnOnOpenSlot3AtStreak is! int ||
        closeOnDraw is! bool ||
        closeOnInvalidAction is! bool ||
        maxSlots is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        BonusSlotsConfig(
          enabled: enabled,
          spawnPolicy: BonusSlotSpawnPolicy.values.byName(spawnPolicy),
          defaultAnchorTierWhenUnknown: BonusSlotAnchorTier.values.byName(
            defaultAnchorTierWhenUnknown,
          ),
          lowTierAnchorRank: Rank.values.byName(lowTierAnchorRank),
          highTierAnchorRank: Rank.values.byName(highTierAnchorRank),
          jokerAcceptsAnyRank: jokerAcceptsAnyRank,
          jokerConsumedOnFirstUse: jokerConsumedOnFirstUse,
          spawnOnOpenSlot2AtStreak: spawnOnOpenSlot2AtStreak,
          spawnOnOpenSlot3AtStreak: spawnOnOpenSlot3AtStreak,
          closeOnDraw: closeOnDraw,
          closeOnInvalidAction: closeOnInvalidAction,
          maxSlots: maxSlots,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsConfig payload: $error',
        ),
      );
    }
  }
}

/// Bonus-slots runtime state for one round.
final class BonusSlotsState {
  /// Creates bonus-slots state.
  const BonusSlotsState({
    required this.slots,
    required this.openSlotsCount,
    required this.lastUsedSlot,
  });

  /// Initial bonus-slots state.
  static const BonusSlotsState initial = BonusSlotsState(
    slots: <List<Card>>[
      <Card>[],
      <Card>[],
      <Card>[],
    ],
    openSlotsCount: 1,
    lastUsedSlot: null,
  );

  /// A 3-slot set of waste stacks from bottom to top.
  ///
  /// Slot indices are 1-based in APIs and 0-based in this list.
  final List<List<Card>> slots;

  /// Number of open slots, in range 1..3.
  final int openSlotsCount;

  /// Last used slot index (1-based), when explicit slot-use action occurs.
  final int? lastUsedSlot;

  /// Returns a copy with optional changes.
  BonusSlotsState copyWith({
    List<List<Card>>? slots,
    int? openSlotsCount,
    int? lastUsedSlot,
    bool clearLastUsedSlot = false,
  }) {
    return BonusSlotsState(
      slots: slots ?? this.slots,
      openSlotsCount: openSlotsCount ?? this.openSlotsCount,
      lastUsedSlot:
          clearLastUsedSlot ? null : (lastUsedSlot ?? this.lastUsedSlot),
    );
  }

  /// Serializes state to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'bonus_slots_state',
      'slots': slots
          .map(
            (slot) => slot.map((card) => card.toMap()).toList(growable: false),
          )
          .toList(growable: false),
      'openSlotsCount': openSlotsCount,
      if (lastUsedSlot case final value?) 'lastUsedSlot': value,
    };
  }

  /// Decodes state from map without throwing.
  static DecodeResult<BonusSlotsState> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'bonus_slots_state') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final slotsRaw = map['slots'];
    final openSlotsCount = map['openSlotsCount'];
    final lastUsedSlot = map['lastUsedSlot'];
    if (openSlotsCount is! int ||
        (lastUsedSlot != null && lastUsedSlot is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid BonusSlotsState payload.',
        ),
      );
    }

    final slots = <List<Card>>[
      <Card>[],
      <Card>[],
      <Card>[],
    ];
    if (slotsRaw != null) {
      if (slotsRaw is! List<dynamic> || slotsRaw.length != 3) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Bonus slots must be a list of exactly 3 slots.',
          ),
        );
      }
      for (var slotIndex = 0; slotIndex < slotsRaw.length; slotIndex++) {
        final slotRaw = slotsRaw[slotIndex];
        if (slotRaw is! List<dynamic>) {
          return const DecodeResult.failure(
            DecodeFailure(
              code: DecodeFailureCode.invalidPayload,
              message: 'Each bonus slot must be a list.',
            ),
          );
        }
        final slotCards = <Card>[];
        for (final rawCard in slotRaw) {
          if (rawCard is! Map<String, dynamic>) {
            return const DecodeResult.failure(
              DecodeFailure(
                code: DecodeFailureCode.invalidPayload,
                message: 'Bonus slot cards must be maps.',
              ),
            );
          }
          final cardResult = Card.tryFromMap(rawCard);
          if (!cardResult.isSuccess) {
            return DecodeResult.failure(cardResult.error!);
          }
          slotCards.add(cardResult.value!);
        }
        slots[slotIndex] = List<Card>.unmodifiable(slotCards);
      }
    }
    return DecodeResult.success(
      BonusSlotsState(
        slots: List<List<Card>>.unmodifiable(slots),
        openSlotsCount: openSlotsCount,
        lastUsedSlot: lastUsedSlot as int?,
      ),
    );
  }
}

/// Deterministic hint selection strategy.
enum HintSelectionStrategy {
  firstPlayableByIndex,
}

/// Configurable hint behavior.
final class HintConfig {
  /// Creates a hint config.
  const HintConfig({
    this.enabled = true,
    this.selectionStrategy = HintSelectionStrategy.firstPlayableByIndex,
  });

  /// Whether hints are enabled.
  final bool enabled;

  /// Strategy for selecting a single hint from playable moves.
  final HintSelectionStrategy selectionStrategy;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'hint_config',
      'enabled': enabled,
      'selectionStrategy': selectionStrategy.name,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<HintConfig> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'hint_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final enabled = map['enabled'];
    final selectionName = map['selectionStrategy'];
    if (enabled is! bool || selectionName is! String) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid HintConfig payload.',
        ),
      );
    }
    try {
      return DecodeResult.success(
        HintConfig(
          enabled: enabled,
          selectionStrategy: HintSelectionStrategy.values.byName(selectionName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid HintConfig payload: $error',
        ),
      );
    }
  }
}

/// Configurable scoring values for match/session-level aggregation.
