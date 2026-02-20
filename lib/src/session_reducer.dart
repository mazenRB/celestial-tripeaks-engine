part of '../tripeaks_engine.dart';

TriPeaksSessionState reduceTriPeaksSession(
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  final result = tryReduceTriPeaksSession(state, action, tick: tick);
  if (result.isSuccess) {
    return result.state;
  }
  if (result.sessionError case final sessionError?) {
    throw StateError(sessionError.message);
  }
  throw StateError(result.roundError!.message);
}

/// Tries to reduce a multi-round session without throwing.
TriPeaksSessionReduceResult tryReduceTriPeaksSession(
  TriPeaksSessionState state,
  TriPeaksSessionAction action, {
  int? tick,
}) {
  if (state.isSessionFinished) {
    return TriPeaksSessionReduceResult(
      state: state,
      sessionError: const TriPeaksSessionError(
        code: TriPeaksSessionErrorCode.gameAlreadyFinished,
        message: 'Session is already finished.',
      ),
    );
  }

  switch (action) {
    case PlayRoundAction(action: final roundAction):
      if (state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundAlreadyFinished,
            message: 'Current round is finished. Start next round to continue.',
          ),
        );
      }

      final roundResult = tryReduceTriPeaks(
        state.currentRound,
        roundAction,
        tick: tick,
      );
      if (!roundResult.isSuccess) {
        final nextState = identical(roundResult.state, state.currentRound)
            ? state
            : state._copyWith(currentRound: roundResult.state);
        return TriPeaksSessionReduceResult(
          state: nextState,
          roundError: roundResult.error,
        );
      }

      final nextRound = roundResult.state;
      if (!nextRound.isWon && !nextRound.isLost) {
        return TriPeaksSessionReduceResult(
          state: state._copyWith(currentRound: nextRound),
        );
      }

      final completed = state.roundsCompleted + 1;
      final won = state.roundsWon + (nextRound.isWon ? 1 : 0);
      final lost = state.roundsLost + (nextRound.isLost ? 1 : 0);
      final result = RoundResult(
        roundNumber: state.currentRoundNumber,
        outcome: nextRound.isWon ? RoundOutcome.won : RoundOutcome.lost,
      );
      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRound: nextRound,
          roundsCompleted: completed,
          roundsWon: won,
          roundsLost: lost,
          roundResults: <RoundResult>[...state.roundResults, result],
        ),
      );

    case StartNextRoundAction():
      if (!state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundNotFinished,
            message: 'Current round is not finished yet.',
          ),
        );
      }
      if (!state._hasNextRound) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.alreadyOnLastRound,
            message: 'No next round is available.',
          ),
        );
      }
      final nextRoundNumber = state.currentRoundNumber + 1;
      final nextRound = TriPeaksSessionState._buildRoundState(
        roundNumber: nextRoundNumber,
        seed: state.seed,
        roundDecks: state.roundDecks,
        scoreConfig: state.scoreConfig,
        roundRulesConfig: state.roundRulesConfig,
        undoConfig: state.undoConfig,
        streakConfig: state.streakConfig,
      );
      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRoundNumber: nextRoundNumber,
          currentRound: nextRound,
        ),
      );

    case AbortRoundAction(reason: final reason):
      if (state.isCurrentRoundFinished) {
        return TriPeaksSessionReduceResult(
          state: state,
          sessionError: const TriPeaksSessionError(
            code: TriPeaksSessionErrorCode.roundAlreadyFinished,
            message: 'Current round is finished. Start next round to continue.',
          ),
        );
      }

      final abortReason = reason ?? AbortReason.userSkip;
      final completed = state.roundsCompleted + 1;
      final aborted = state.roundsAborted + 1;
      final result = RoundResult(
        roundNumber: state.currentRoundNumber,
        outcome: RoundOutcome.aborted,
        abortReason: abortReason,
      );

      if (!state._hasNextRound) {
        return TriPeaksSessionReduceResult(
          state: state._copyWith(
            roundsCompleted: completed,
            roundsAborted: aborted,
            roundResults: <RoundResult>[...state.roundResults, result],
          ),
        );
      }

      final nextRoundNumber = state.currentRoundNumber + 1;
      final nextRound = TriPeaksSessionState._buildRoundState(
        roundNumber: nextRoundNumber,
        seed: state.seed,
        roundDecks: state.roundDecks,
        scoreConfig: state.scoreConfig,
        roundRulesConfig: state.roundRulesConfig,
        undoConfig: state.undoConfig,
        streakConfig: state.streakConfig,
      );

      return TriPeaksSessionReduceResult(
        state: state._copyWith(
          currentRoundNumber: nextRoundNumber,
          roundsCompleted: completed,
          roundsAborted: aborted,
          roundResults: <RoundResult>[...state.roundResults, result],
          currentRound: nextRound,
        ),
      );
  }
}

TriPeaksRuleError? _validateAction(TriPeaksState state, TriPeaksAction action) {
  switch (action) {
    case DrawFromStockAction():
      if (!state.canDrawFromStock) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.emptyStock,
          message: 'Stock is empty.',
        );
      }
      return null;

    case RemoveTableauCardAction(index: final index):
      if (index < 0 || index >= state.tableau.length) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.invalidTableauIndex,
          message: 'Tableau index $index is out of range.',
        );
      }
      if (!state.canRemoveTableau(index)) {
        return TriPeaksRuleError(
          code: TriPeaksErrorCode.tableauCardNotRemovable,
          message: 'Tableau index $index is not removable.',
        );
      }
      return null;

    case UndoAction():
      if (!state.undoConfig.enabled) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.undoDisabled,
          message: 'Undo is disabled for this round.',
        );
      }
      if (state._undoHistory.isEmpty) {
        return const TriPeaksRuleError(
          code: TriPeaksErrorCode.nothingToUndo,
          message: 'There are no actions to undo.',
        );
      }
      return null;
  }
}

final class _TriPeaksSnapshot {
  const _TriPeaksSnapshot({
    required this.tableau,
    required this.removed,
    required this.waste,
    required this.stock,
    required this.scoreState,
    required this.streakState,
  });

  final List<Card> tableau;
  final List<bool> removed;
  final List<Card> waste;
  final List<Card> stock;
  final ScoreState scoreState;
  final StreakState streakState;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'tripeaks_snapshot',
      'tableau': tableau.map((card) => card.toMap()).toList(growable: false),
      'removed': removed,
      'waste': waste.map((card) => card.toMap()).toList(growable: false),
      'stock': stock.map((card) => card.toMap()).toList(growable: false),
      'scoreState': scoreState.toMap(),
      'streakState': streakState.toMap(),
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
    return DecodeResult.success(
      _TriPeaksSnapshot(
        tableau: tableauResult.value!,
        removed: removed.cast<bool>(),
        waste: wasteResult.value!,
        stock: stockResult.value!,
        scoreState: scoreResult.value!,
        streakState: streakResult.value!,
      ),
    );
  }
}

/// Reduces match-level score state by one explicit scoring [event].
