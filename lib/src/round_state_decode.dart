part of 'tripeaks_engine_internal.dart';

DecodeResult<TriPeaksState> _triPeaksStateTryFromMap(Map<String, dynamic> map) {
  if (map['schemaVersion'] != _serializationSchemaV1) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unsupportedSchemaVersion,
        message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
      ),
    );
  }
  if (map['type'] != 'tripeaks_round_state') {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unknownType,
        message: 'Unknown type ${map['type']}.',
      ),
    );
  }

  final tableauResult = _decodeCardListFromRaw(map['tableau'], 'tableau');
  if (!tableauResult.isSuccess) {
    return DecodeResult.failure(tableauResult.error!);
  }
  final wasteResult = _decodeCardListFromRaw(map['waste'], 'waste');
  if (!wasteResult.isSuccess) {
    return DecodeResult.failure(wasteResult.error!);
  }
  final stockResult = _decodeCardListFromRaw(map['stock'], 'stock');
  if (!stockResult.isSuccess) {
    return DecodeResult.failure(stockResult.error!);
  }
  final roundNumber = map['roundNumber'];
  if (roundNumber != null && roundNumber is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'roundNumber must be int when present.',
      ),
    );
  }

  final removed = map['removed'];
  if (removed is! List<dynamic> || removed.any((item) => item is! bool)) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'removed must be a list of bool.',
      ),
    );
  }

  final roundSeed = map['roundSeed'];
  if (roundSeed != null && roundSeed is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'roundSeed must be int when present.',
      ),
    );
  }

  final bonusAnchorSpawnNonce = map['bonusAnchorSpawnNonce'];
  if (bonusAnchorSpawnNonce != null && bonusAnchorSpawnNonce is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'bonusAnchorSpawnNonce must be int when present.',
      ),
    );
  }

  final scoreConfigMap = map['scoreConfig'];
  if (scoreConfigMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'scoreConfig must be a map.',
      ),
    );
  }
  final scoreConfigResult = ScoreConfig.tryFromMap(scoreConfigMap);
  if (!scoreConfigResult.isSuccess) {
    return DecodeResult.failure(scoreConfigResult.error!);
  }
  final roundRulesMap = map['roundRulesConfig'];
  if (roundRulesMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'roundRulesConfig must be a map.',
      ),
    );
  }
  final roundRulesResult = RoundRulesConfig.tryFromMap(roundRulesMap);
  if (!roundRulesResult.isSuccess) {
    return DecodeResult.failure(roundRulesResult.error!);
  }
  final roundTimerConfigMap = map['roundTimerConfig'];
  DecodeResult<RoundTimerConfig>? roundTimerConfigResult;
  if (roundTimerConfigMap != null) {
    if (roundTimerConfigMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundTimerConfig must be a map when present.',
        ),
      );
    }
    roundTimerConfigResult = RoundTimerConfig.tryFromMap(roundTimerConfigMap);
    if (!roundTimerConfigResult.isSuccess) {
      return DecodeResult.failure(roundTimerConfigResult.error!);
    }
  }
  final undoConfigMap = map['undoConfig'];
  if (undoConfigMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'undoConfig must be a map.',
      ),
    );
  }
  final undoConfigResult = UndoConfig.tryFromMap(undoConfigMap);
  if (!undoConfigResult.isSuccess) {
    return DecodeResult.failure(undoConfigResult.error!);
  }
  final streakConfigMap = map['streakConfig'];
  if (streakConfigMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'streakConfig must be a map.',
      ),
    );
  }
  final streakConfigResult = StreakConfig.tryFromMap(streakConfigMap);
  if (!streakConfigResult.isSuccess) {
    return DecodeResult.failure(streakConfigResult.error!);
  }
  final strikeTimerConfigMap = map['strikeTimerConfig'];
  if (strikeTimerConfigMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'strikeTimerConfig must be a map.',
      ),
    );
  }
  final strikeTimerConfigResult = StrikeTimerConfig.tryFromMap(
    strikeTimerConfigMap,
  );
  if (!strikeTimerConfigResult.isSuccess) {
    return DecodeResult.failure(strikeTimerConfigResult.error!);
  }
  final bonusSlotsConfigMap = map['bonusSlotsConfig'];
  if (bonusSlotsConfigMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'bonusSlotsConfig must be a map.',
      ),
    );
  }
  final bonusSlotsConfigResult = BonusSlotsConfig.tryFromMap(
    bonusSlotsConfigMap,
  );
  if (!bonusSlotsConfigResult.isSuccess) {
    return DecodeResult.failure(bonusSlotsConfigResult.error!);
  }
  final scoreStateMap = map['scoreState'];
  if (scoreStateMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'scoreState must be a map.',
      ),
    );
  }
  final scoreStateResult = ScoreState.tryFromMap(scoreStateMap);
  if (!scoreStateResult.isSuccess) {
    return DecodeResult.failure(scoreStateResult.error!);
  }
  final streakStateMap = map['streakState'];
  if (streakStateMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'streakState must be a map.',
      ),
    );
  }
  final streakStateResult = StreakState.tryFromMap(streakStateMap);
  if (!streakStateResult.isSuccess) {
    return DecodeResult.failure(streakStateResult.error!);
  }
  final roundTimerStateMap = map['roundTimerState'];
  DecodeResult<RoundTimerState>? roundTimerStateResult;
  if (roundTimerStateMap != null) {
    if (roundTimerStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundTimerState must be a map when present.',
        ),
      );
    }
    roundTimerStateResult = RoundTimerState.tryFromMap(roundTimerStateMap);
    if (!roundTimerStateResult.isSuccess) {
      return DecodeResult.failure(roundTimerStateResult.error!);
    }
  }
  final strikeTimerStateMap = map['strikeTimerState'];
  if (strikeTimerStateMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'strikeTimerState must be a map.',
      ),
    );
  }
  final strikeTimerStateResult = StrikeTimerState.tryFromMap(
    strikeTimerStateMap,
  );
  if (!strikeTimerStateResult.isSuccess) {
    return DecodeResult.failure(strikeTimerStateResult.error!);
  }
  final timeBonusTimerStateMap = map['timeBonusTimerState'];
  DecodeResult<TimeBonusTimerState>? timeBonusTimerStateResult;
  if (timeBonusTimerStateMap != null) {
    if (timeBonusTimerStateMap is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'timeBonusTimerState must be a map when present.',
        ),
      );
    }
    timeBonusTimerStateResult = TimeBonusTimerState.tryFromMap(
      timeBonusTimerStateMap,
    );
    if (!timeBonusTimerStateResult.isSuccess) {
      return DecodeResult.failure(timeBonusTimerStateResult.error!);
    }
  }
  final lastSuccessfulTableauRank = map['lastSuccessfulTableauRank'];
  if (lastSuccessfulTableauRank != null &&
      lastSuccessfulTableauRank is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'lastSuccessfulTableauRank must be a string when present.',
      ),
    );
  }
  Rank? decodedLastSuccessfulTableauRank;
  if (lastSuccessfulTableauRank case final rankName?) {
    try {
      decodedLastSuccessfulTableauRank = Rank.values.byName(rankName);
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid lastSuccessfulTableauRank: $error',
        ),
      );
    }
  }
  final bonusSlotsStateMap = map['bonusSlotsState'];
  if (bonusSlotsStateMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'bonusSlotsState must be a map.',
      ),
    );
  }
  final bonusSlotsStateResult = BonusSlotsState.tryFromMap(
    bonusSlotsStateMap,
  );
  if (!bonusSlotsStateResult.isSuccess) {
    return DecodeResult.failure(bonusSlotsStateResult.error!);
  }
  final clearedPeaksAwardedMask = map['clearedPeaksAwardedMask'];
  if (clearedPeaksAwardedMask != null && clearedPeaksAwardedMask is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'clearedPeaksAwardedMask must be int when present.',
      ),
    );
  }

  final historyRaw = map['undoHistory'];
  if (historyRaw is! List<dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'undoHistory must be a list.',
      ),
    );
  }
  final history = <_TriPeaksSnapshot>[];
  for (final item in historyRaw) {
    if (item is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'undoHistory items must be maps.',
        ),
      );
    }
    final snapshotResult = _TriPeaksSnapshot.tryFromMap(item);
    if (!snapshotResult.isSuccess) {
      return DecodeResult.failure(snapshotResult.error!);
    }
    history.add(snapshotResult.value!);
  }

  final decodedBonusSlots = bonusSlotsStateResult.value!;
  final normalizedSlots = <List<Card>>[
    ...decodedBonusSlots.slots,
  ];
  if (normalizedSlots.first.isEmpty && wasteResult.value!.isNotEmpty) {
    normalizedSlots[0] = wasteResult.value!;
  }
  final normalizedBonusSlots = decodedBonusSlots.copyWith(
    slots: List<List<Card>>.unmodifiable(
      normalizedSlots
          .map((slot) => List<Card>.unmodifiable(slot))
          .toList(growable: false),
    ),
  );
  final normalizedWaste = List<Card>.unmodifiable(normalizedSlots.first);
  final roundStatusName = map['roundStatus'];
  if (roundStatusName != null && roundStatusName is! String) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'roundStatus must be a string when present.',
      ),
    );
  }
  RoundStatus roundStatus = RoundStatus.inProgress;
  if (roundStatusName case final name?) {
    try {
      roundStatus = RoundStatus.values.byName(name);
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid roundStatus: $error',
        ),
      );
    }
  }
  final resolvedRoundNumber = roundNumber as int? ?? 1;
  final resolvedRoundTimerConfig =
      roundTimerConfigResult?.value ?? const RoundTimerConfig();
  if (_roundTimerConfigValidationMessageForRound(
    resolvedRoundTimerConfig,
    resolvedRoundNumber,
  )
      case final timerError?) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: timerError,
      ),
    );
  }
  final resolvedRoundTimerState = roundTimerStateResult?.value ??
      _initialRoundTimerState(resolvedRoundTimerConfig, resolvedRoundNumber);

  return DecodeResult.success(
    TriPeaksState._(
      tableau: tableauResult.value!,
      removed: removed.cast<bool>(),
      waste: normalizedWaste,
      stock: stockResult.value!,
      roundNumber: resolvedRoundNumber,
      roundSeed: roundSeed as int? ?? TriPeaksState.defaultSeed,
      scoreConfig: scoreConfigResult.value!,
      roundRulesConfig: roundRulesResult.value!,
      roundTimerConfig: resolvedRoundTimerConfig,
      undoConfig: undoConfigResult.value!,
      streakConfig: streakConfigResult.value!,
      strikeTimerConfig: strikeTimerConfigResult.value!,
      bonusSlotsConfig: bonusSlotsConfigResult.value!,
      roundStatus: roundStatus,
      scoreState: scoreStateResult.value!,
      streakState: streakStateResult.value!,
      roundTimerState: resolvedRoundTimerState,
      strikeTimerState: strikeTimerStateResult.value!,
      timeBonusTimerState:
          timeBonusTimerStateResult?.value ?? TimeBonusTimerState.initial,
      bonusSlotsState: normalizedBonusSlots,
      lastSuccessfulTableauRank: decodedLastSuccessfulTableauRank,
      clearedPeaksAwardedMask: clearedPeaksAwardedMask as int? ?? 0,
      bonusAnchorSpawnNonce: bonusAnchorSpawnNonce as int? ?? 0,
      undoHistory: history,
    ),
  );
}

DecodeResult<List<Card>> _decodeCardListFromRaw(Object? raw, String name) {
  if (raw is! List<dynamic>) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: '$name must be a list.',
      ),
    );
  }
  final cards = <Card>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: '$name items must be maps.',
        ),
      );
    }
    final decoded = Card.tryFromMap(item);
    if (!decoded.isSuccess) {
      return DecodeResult.failure(decoded.error!);
    }
    cards.add(decoded.value!);
  }
  return DecodeResult.success(List<Card>.unmodifiable(cards));
}
