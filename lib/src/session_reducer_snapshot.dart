part of '../tripeaks_engine.dart';

final class _TriPeaksSnapshot {
  const _TriPeaksSnapshot({
    required this.tableau,
    required this.removed,
    required this.waste,
    required this.stock,
    required this.roundNumber,
    required this.roundStatus,
    required this.scoreState,
    required this.streakState,
    required this.roundTimerState,
    required this.strikeTimerState,
    required this.timeBonusTimerState,
    required this.bonusSlotsState,
    required this.lastSuccessfulTableauRank,
    required this.clearedPeaksAwardedMask,
    required this.bonusAnchorSpawnNonce,
  });

  final List<Card> tableau;
  final List<bool> removed;
  final List<Card> waste;
  final List<Card> stock;
  final int roundNumber;
  final RoundStatus roundStatus;
  final ScoreState scoreState;
  final StreakState streakState;
  final RoundTimerState roundTimerState;
  final StrikeTimerState strikeTimerState;
  final TimeBonusTimerState timeBonusTimerState;
  final BonusSlotsState bonusSlotsState;
  final Rank? lastSuccessfulTableauRank;
  final int clearedPeaksAwardedMask;
  final int bonusAnchorSpawnNonce;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_snapshot',
      'tableau': tableau.map((card) => card.toMap()).toList(growable: false),
      'removed': removed,
      'waste': waste.map((card) => card.toMap()).toList(growable: false),
      'stock': stock.map((card) => card.toMap()).toList(growable: false),
      'roundNumber': roundNumber,
      'roundStatus': roundStatus.name,
      'scoreState': scoreState.toMap(),
      'streakState': streakState.toMap(),
      'roundTimerState': roundTimerState.toMap(),
      'strikeTimerState': strikeTimerState.toMap(),
      'timeBonusTimerState': timeBonusTimerState.toMap(),
      'bonusSlotsState': bonusSlotsState.toMap(),
      if (lastSuccessfulTableauRank case final rank?)
        'lastSuccessfulTableauRank': rank.name,
      'clearedPeaksAwardedMask': clearedPeaksAwardedMask,
      'bonusAnchorSpawnNonce': bonusAnchorSpawnNonce,
    };
  }

  static DecodeResult<_TriPeaksSnapshot> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'tripeaks_snapshot') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final tableauResult =
        TriPeaksState._decodeCardList(map['tableau'], 'tableau');
    if (!tableauResult.isSuccess) {
      return DecodeResult.failure(tableauResult.error!);
    }
    final wasteResult = TriPeaksState._decodeCardList(map['waste'], 'waste');
    if (!wasteResult.isSuccess) {
      return DecodeResult.failure(wasteResult.error!);
    }
    final stockResult = TriPeaksState._decodeCardList(map['stock'], 'stock');
    if (!stockResult.isSuccess) {
      return DecodeResult.failure(stockResult.error!);
    }
    final roundNumber = map['roundNumber'];
    if (roundNumber is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'roundNumber must be int.',
        ),
      );
    }
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
    final removed = map['removed'];
    if (removed is! List<dynamic> || removed.any((value) => value is! bool)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'removed must be a list of bool.',
        ),
      );
    }
    final scoreResult = ScoreState.tryFromMap(
      map['scoreState'] as Map<String, dynamic>,
    );
    if (!scoreResult.isSuccess) {
      return DecodeResult.failure(scoreResult.error!);
    }
    final streakResult = StreakState.tryFromMap(
      map['streakState'] as Map<String, dynamic>,
    );
    if (!streakResult.isSuccess) {
      return DecodeResult.failure(streakResult.error!);
    }
    final roundTimerStateMap = map['roundTimerState'];
    DecodeResult<RoundTimerState>? roundTimerResult;
    if (roundTimerStateMap != null) {
      if (roundTimerStateMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'roundTimerState must be a map when present.',
          ),
        );
      }
      roundTimerResult = RoundTimerState.tryFromMap(roundTimerStateMap);
      if (!roundTimerResult.isSuccess) {
        return DecodeResult.failure(roundTimerResult.error!);
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
    final strikeTimerResult = StrikeTimerState.tryFromMap(strikeTimerStateMap);
    if (!strikeTimerResult.isSuccess) {
      return DecodeResult.failure(strikeTimerResult.error!);
    }
    final timeBonusTimerStateMap = map['timeBonusTimerState'];
    DecodeResult<TimeBonusTimerState>? timeBonusTimerResult;
    if (timeBonusTimerStateMap != null) {
      if (timeBonusTimerStateMap is! Map<String, dynamic>) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'timeBonusTimerState must be a map when present.',
          ),
        );
      }
      timeBonusTimerResult = TimeBonusTimerState.tryFromMap(
        timeBonusTimerStateMap,
      );
      if (!timeBonusTimerResult.isSuccess) {
        return DecodeResult.failure(timeBonusTimerResult.error!);
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
    final bonusSlotsResult = BonusSlotsState.tryFromMap(bonusSlotsStateMap);
    if (!bonusSlotsResult.isSuccess) {
      return DecodeResult.failure(bonusSlotsResult.error!);
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
    final clearedPeaksAwardedMask = map['clearedPeaksAwardedMask'];
    final bonusAnchorSpawnNonce = map['bonusAnchorSpawnNonce'];
    if (clearedPeaksAwardedMask is! int ||
        (bonusAnchorSpawnNonce != null && bonusAnchorSpawnNonce is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message:
              'clearedPeaksAwardedMask and bonusAnchorSpawnNonce must be int.',
        ),
      );
    }
    return DecodeResult.success(
      _TriPeaksSnapshot(
        tableau: tableauResult.value!,
        removed: removed.cast<bool>(),
        waste: wasteResult.value!,
        stock: stockResult.value!,
        roundNumber: roundNumber,
        roundStatus: roundStatus,
        scoreState: scoreResult.value!,
        streakState: streakResult.value!,
        roundTimerState: roundTimerResult?.value ?? RoundTimerState.initial,
        strikeTimerState: strikeTimerResult.value!,
        timeBonusTimerState:
            timeBonusTimerResult?.value ?? TimeBonusTimerState.initial,
        bonusSlotsState: bonusSlotsResult.value!,
        lastSuccessfulTableauRank: decodedLastSuccessfulTableauRank,
        clearedPeaksAwardedMask: clearedPeaksAwardedMask,
        bonusAnchorSpawnNonce: bonusAnchorSpawnNonce as int? ?? 0,
      ),
    );
  }
}
