part of '../tripeaks_engine.dart';

List<int> getPlayableMoves(
  TriPeaksState state,
  RoundRulesConfig rulesConfig,
) {
  final playable = <int>[];
  for (final index in state.exposedTableauIndices) {
    final isPlayable = TriPeaksState._areAdjacentRanks(
      state.tableau[index].rank,
      state.wasteTop.rank,
      rulesConfig,
    );
    if (isPlayable) {
      playable.add(index);
    }
  }
  return List<int>.unmodifiable(playable);
}

/// Returns a deterministic hint for [state] using [hintConfig].
HintResult getHint(
  TriPeaksState state,
  RoundRulesConfig rulesConfig,
  HintConfig hintConfig,
) {
  if (!hintConfig.enabled) {
    return const HintResult(
      error: HintError(
        code: HintErrorCode.hintDisabled,
        message: 'Hints are disabled.',
      ),
    );
  }

  final playableMoves = getPlayableMoves(state, rulesConfig);
  if (playableMoves.isEmpty) {
    return const HintResult(
      error: HintError(
        code: HintErrorCode.noHintAvailable,
        message: 'No playable moves are available.',
      ),
    );
  }

  switch (hintConfig.selectionStrategy) {
    case HintSelectionStrategy.firstPlayableByIndex:
      return HintResult(moveIndex: playableMoves.first);
  }
}

/// Reduces [state] by applying one [action], returning a new immutable state.
