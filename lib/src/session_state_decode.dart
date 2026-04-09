part of '../tripeaks_engine.dart';

DecodeResult<TriPeaksSessionState> _decodeTriPeaksSessionState(
  Map<String, dynamic> map,
) {
  if (map['schemaVersion'] != _serializationSchemaV1) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unsupportedSchemaVersion,
        message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
      ),
    );
  }
  if (map['type'] != 'tripeaks_session_state') {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.unknownType,
        message: 'Unknown type ${map['type']}.',
      ),
    );
  }

  final rulesetMap = map['ruleset'];
  if (rulesetMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'ruleset must be a map.',
      ),
    );
  }
  final rulesetResult = TriPeaksRuleset.tryFromMap(rulesetMap);
  if (!rulesetResult.isSuccess) {
    return DecodeResult.failure(rulesetResult.error!);
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
  final seedRaw = map['seed'];
  if (seedRaw != null && seedRaw is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'seed must be int when present.',
      ),
    );
  }
  final currentRoundNumber = map['currentRoundNumber'];
  final roundsCompleted = map['roundsCompleted'];
  final roundsWon = map['roundsWon'];
  final roundsLost = map['roundsLost'];
  final roundsTimedOut = map['roundsTimedOut'];
  final roundsAborted = map['roundsAborted'];
  if (currentRoundNumber is! int ||
      roundsCompleted is! int ||
      roundsWon is! int ||
      roundsLost is! int ||
      (roundsTimedOut != null && roundsTimedOut is! int) ||
      roundsAborted is! int) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'Invalid session numeric payload.',
      ),
    );
  }

  final currentRoundMap = map['currentRound'];
  if (currentRoundMap is! Map<String, dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'currentRound must be a map.',
      ),
    );
  }
  final currentRoundResult = TriPeaksState.tryFromMap(currentRoundMap);
  if (!currentRoundResult.isSuccess) {
    return DecodeResult.failure(currentRoundResult.error!);
  }
  final hasRoundSeed = currentRoundMap['roundSeed'] is int;
  final decodedRound = currentRoundResult.value!;
  final effectiveSessionSeed =
      (seedRaw as int?) ?? TriPeaksSessionState.defaultSeed;
  final derivedRoundSeed = effectiveSessionSeed + currentRoundNumber - 1;
  final currentRound = hasRoundSeed
      ? decodedRound
      : decodedRound._copyWith(roundSeed: derivedRoundSeed);

  final roundResultsRaw = map['roundResults'];
  if (roundResultsRaw is! List<dynamic>) {
    return const DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: 'roundResults must be a list.',
      ),
    );
  }
  final roundResults = <RoundResult>[];
  for (final raw in roundResultsRaw) {
    if (raw is! Map<String, dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundResults items must be maps.',
        ),
      );
    }
    final decoded = RoundResult.tryFromMap(raw);
    if (!decoded.isSuccess) {
      return DecodeResult.failure(decoded.error!);
    }
    roundResults.add(decoded.value!);
  }

  final roundDecksRaw = map['roundDecks'];
  List<List<Card>>? roundDecks;
  if (roundDecksRaw != null) {
    if (roundDecksRaw is! List<dynamic>) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundDecks must be a list when present.',
        ),
      );
    }
    roundDecks = <List<Card>>[];
    for (final rawDeck in roundDecksRaw) {
      final decodedDeck = TriPeaksState._decodeCardList(rawDeck, 'roundDeck');
      if (!decodedDeck.isSuccess) {
        return DecodeResult.failure(decodedDeck.error!);
      }
      roundDecks.add(decodedDeck.value!);
    }
  }
  final resolvedRoundTimerConfig =
      roundTimerConfigResult?.value ?? const RoundTimerConfig();
  if (_roundTimerConfigValidationMessage(
        resolvedRoundTimerConfig,
        rulesetResult.value!.roundsPerGame,
      ) case final timerError?) {
    return DecodeResult.failure(
      DecodeFailure(
        code: DecodeFailureCode.invalidPayload,
        message: timerError,
      ),
    );
  }

  return DecodeResult.success(
    TriPeaksSessionState._(
      ruleset: rulesetResult.value!,
      seed: seedRaw,
      roundDecks: roundDecks == null
          ? null
          : List<List<Card>>.unmodifiable(
              roundDecks.map(List<Card>.unmodifiable),
            ),
      scoreConfig: scoreConfigResult.value!,
      roundRulesConfig: roundRulesResult.value!,
      roundTimerConfig: resolvedRoundTimerConfig,
      undoConfig: undoConfigResult.value!,
      streakConfig: streakConfigResult.value!,
      strikeTimerConfig: strikeTimerConfigResult.value!,
      bonusSlotsConfig: bonusSlotsConfigResult.value!,
      currentRoundNumber: currentRoundNumber,
      roundsCompleted: roundsCompleted,
      roundsWon: roundsWon,
      roundsLost: roundsLost,
      roundsTimedOut: roundsTimedOut as int? ?? 0,
      roundsAborted: roundsAborted,
      roundResults: List<RoundResult>.unmodifiable(roundResults),
      currentRound: currentRound,
    ),
  );
}
