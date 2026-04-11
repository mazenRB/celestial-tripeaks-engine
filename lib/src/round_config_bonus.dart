part of 'tripeaks_engine_internal.dart';

/// Configurable bonus-slot spawn behavior linked to streak progression.
enum BonusSlotSpawnPolicy {
  joker,
  tierFixedRank,
  tierRandomRank,

  /// Opens newly unlocked slot 2/3 by consuming the next stock card.
  stockTopCard,
}

/// Tier used when spawning deterministic anchor cards.
enum BonusSlotAnchorTier {
  low,
  high,
}

/// Configurable bonus-slot behavior linked to streak progression.
///
/// The waste pile is the primary playable pile. Bonus slots are additional
/// playable piles layered on top of that core flow.
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

  /// Whether bonus-slot mechanics beyond the primary waste pile are enabled.
  final bool enabled;

  /// Spawn behavior used when newly opened bonus slots need an initial top card.
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
  /// Slot `1` mirrors the waste pile and is always available.
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

  /// A 3-slot set of playable piles from bottom to top.
  ///
  /// Slot `1` is the primary waste pile. Slot indices are 1-based in public
  /// APIs and 0-based in this list.
  final List<List<Card>> slots;

  /// Number of slots actually open now, in range 1..3.
  ///
  /// This may be lower than streak-threshold entitlement when a spawn policy
  /// requires additional resources, such as stock availability.
  final int openSlotsCount;

  /// Last explicitly used slot index (1-based).
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
