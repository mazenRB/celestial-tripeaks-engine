part of 'tripeaks_engine_internal.dart';

/// Completion status for one independently played run.
enum CompletedRunStatus {
  completed,
  incomplete,
}

/// Serializable summary of one completed deterministic session run.
final class CompletedSessionResult {
  /// Creates a completed session result.
  const CompletedSessionResult({
    required this.schemaVersion,
    required this.engineVersion,
    required this.seed,
    required this.ruleset,
    required this.scoreConfig,
    required this.roundRulesConfig,
    required this.roundTimerConfig,
    required this.undoConfig,
    required this.streakConfig,
    required this.strikeTimerConfig,
    required this.bonusSlotsConfig,
    required this.status,
    required this.finalScore,
    required this.finalFingerprint,
    required this.roundsCompleted,
    required this.roundsWon,
    required this.roundsLost,
    required this.roundsTimedOut,
    required this.roundsAborted,
  });

  /// Creates a neutral result snapshot from [session].
  factory CompletedSessionResult.fromSession(TriPeaksSessionState session) {
    return CompletedSessionResult(
      schemaVersion: _serializationSchemaV1,
      engineVersion: 1,
      seed: session.seed ?? TriPeaksSessionState.defaultSeed,
      ruleset: session.ruleset,
      scoreConfig: session.scoreConfig,
      roundRulesConfig: session.roundRulesConfig,
      roundTimerConfig: session.roundTimerConfig,
      undoConfig: session.undoConfig,
      streakConfig: session.streakConfig,
      strikeTimerConfig: session.strikeTimerConfig,
      bonusSlotsConfig: session.bonusSlotsConfig,
      status: session.isSessionFinished
          ? CompletedRunStatus.completed
          : CompletedRunStatus.incomplete,
      finalScore: session.cumulativeIncludingCurrentRoundScoreTotal,
      finalFingerprint: sessionFingerprint(session),
      roundsCompleted: session.roundsCompleted,
      roundsWon: session.roundsWon,
      roundsLost: session.roundsLost,
      roundsTimedOut: session.roundsTimedOut,
      roundsAborted: session.roundsAborted,
    );
  }

  /// Schema version for this payload.
  final int schemaVersion;

  /// Engine version metadata.
  final int engineVersion;

  /// Deterministic seed used for the run.
  final int seed;

  /// Ruleset used for the run.
  final TriPeaksRuleset ruleset;

  /// Score configuration used for the run.
  final ScoreConfig scoreConfig;

  /// Round rules configuration used for the run.
  final RoundRulesConfig roundRulesConfig;

  /// Round timer configuration used for the run.
  final RoundTimerConfig roundTimerConfig;

  /// Undo configuration used for the run.
  final UndoConfig undoConfig;

  /// Streak configuration used for the run.
  final StreakConfig streakConfig;

  /// Strike timer configuration used for the run.
  final StrikeTimerConfig strikeTimerConfig;

  /// Bonus-slots configuration used for the run.
  final BonusSlotsConfig bonusSlotsConfig;

  /// Completion status for the run.
  final CompletedRunStatus status;

  /// Final deterministic score for the run.
  final int finalScore;

  /// Final deterministic fingerprint for the run.
  final String finalFingerprint;

  /// Completed rounds count.
  final int roundsCompleted;

  /// Won rounds count.
  final int roundsWon;

  /// Lost rounds count.
  final int roundsLost;

  /// Timed-out rounds count.
  final int roundsTimedOut;

  /// Aborted rounds count.
  final int roundsAborted;

  /// Whether this run can be compared with [other] under the same rules.
  bool isComparableTo(CompletedSessionResult other) {
    return seed == other.seed &&
        ruleset == other.ruleset &&
        _mapsEqual(scoreConfig.toMap(), other.scoreConfig.toMap()) &&
        _mapsEqual(
          roundRulesConfig.toMap(),
          other.roundRulesConfig.toMap(),
        ) &&
        _mapsEqual(
          roundTimerConfig.toMap(),
          other.roundTimerConfig.toMap(),
        ) &&
        _mapsEqual(undoConfig.toMap(), other.undoConfig.toMap()) &&
        _mapsEqual(streakConfig.toMap(), other.streakConfig.toMap()) &&
        _mapsEqual(
          strikeTimerConfig.toMap(),
          other.strikeTimerConfig.toMap(),
        ) &&
        _mapsEqual(
          bonusSlotsConfig.toMap(),
          other.bonusSlotsConfig.toMap(),
        );
  }

  /// Serializes the result to map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'type': 'completed_session_result',
      'engineVersion': engineVersion,
      'seed': seed,
      'ruleset': ruleset.toMap(),
      'scoreConfig': scoreConfig.toMap(),
      'roundRulesConfig': roundRulesConfig.toMap(),
      'roundTimerConfig': roundTimerConfig.toMap(),
      'undoConfig': undoConfig.toMap(),
      'streakConfig': streakConfig.toMap(),
      'strikeTimerConfig': strikeTimerConfig.toMap(),
      'bonusSlotsConfig': bonusSlotsConfig.toMap(),
      'status': status.name,
      'finalScore': finalScore,
      'finalFingerprint': finalFingerprint,
      'roundsCompleted': roundsCompleted,
      'roundsWon': roundsWon,
      'roundsLost': roundsLost,
      'roundsTimedOut': roundsTimedOut,
      'roundsAborted': roundsAborted,
    };
  }

  /// Decodes a completed session result from map without throwing.
  static DecodeResult<CompletedSessionResult> tryFromMap(
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
    if (map['type'] != 'completed_session_result') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }

    final engineVersion = map['engineVersion'];
    final seed = map['seed'];
    final rulesetMap = map['ruleset'];
    final scoreConfigMap = map['scoreConfig'];
    final roundRulesConfigMap = map['roundRulesConfig'];
    final roundTimerConfigMap = map['roundTimerConfig'];
    final undoConfigMap = map['undoConfig'];
    final streakConfigMap = map['streakConfig'];
    final strikeTimerConfigMap = map['strikeTimerConfig'];
    final bonusSlotsConfigMap = map['bonusSlotsConfig'];
    final statusName = map['status'];
    final finalScore = map['finalScore'];
    final finalFingerprint = map['finalFingerprint'];
    final roundsCompleted = map['roundsCompleted'];
    final roundsWon = map['roundsWon'];
    final roundsLost = map['roundsLost'];
    final roundsTimedOut = map['roundsTimedOut'];
    final roundsAborted = map['roundsAborted'];
    if (engineVersion is! int ||
        seed is! int ||
        rulesetMap is! Map<String, dynamic> ||
        scoreConfigMap is! Map<String, dynamic> ||
        roundRulesConfigMap is! Map<String, dynamic> ||
        roundTimerConfigMap is! Map<String, dynamic> ||
        undoConfigMap is! Map<String, dynamic> ||
        streakConfigMap is! Map<String, dynamic> ||
        strikeTimerConfigMap is! Map<String, dynamic> ||
        bonusSlotsConfigMap is! Map<String, dynamic> ||
        statusName is! String ||
        finalScore is! int ||
        finalFingerprint is! String ||
        roundsCompleted is! int ||
        roundsWon is! int ||
        roundsLost is! int ||
        roundsTimedOut is! int ||
        roundsAborted is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid completed session result payload.',
        ),
      );
    }

    final ruleset = TriPeaksRuleset.tryFromMap(rulesetMap);
    if (!ruleset.isSuccess) {
      return DecodeResult.failure(ruleset.error!);
    }
    final scoreConfig = ScoreConfig.tryFromMap(scoreConfigMap);
    if (!scoreConfig.isSuccess) {
      return DecodeResult.failure(scoreConfig.error!);
    }
    final roundRulesConfig = RoundRulesConfig.tryFromMap(roundRulesConfigMap);
    if (!roundRulesConfig.isSuccess) {
      return DecodeResult.failure(roundRulesConfig.error!);
    }
    final roundTimerConfig = RoundTimerConfig.tryFromMap(roundTimerConfigMap);
    if (!roundTimerConfig.isSuccess) {
      return DecodeResult.failure(roundTimerConfig.error!);
    }
    final undoConfig = UndoConfig.tryFromMap(undoConfigMap);
    if (!undoConfig.isSuccess) {
      return DecodeResult.failure(undoConfig.error!);
    }
    final streakConfig = StreakConfig.tryFromMap(streakConfigMap);
    if (!streakConfig.isSuccess) {
      return DecodeResult.failure(streakConfig.error!);
    }
    final strikeTimerConfig =
        StrikeTimerConfig.tryFromMap(strikeTimerConfigMap);
    if (!strikeTimerConfig.isSuccess) {
      return DecodeResult.failure(strikeTimerConfig.error!);
    }
    final bonusSlotsConfig = BonusSlotsConfig.tryFromMap(bonusSlotsConfigMap);
    if (!bonusSlotsConfig.isSuccess) {
      return DecodeResult.failure(bonusSlotsConfig.error!);
    }

    try {
      return DecodeResult.success(
        CompletedSessionResult(
          schemaVersion: _serializationSchemaV1,
          engineVersion: engineVersion,
          seed: seed,
          ruleset: ruleset.value!,
          scoreConfig: scoreConfig.value!,
          roundRulesConfig: roundRulesConfig.value!,
          roundTimerConfig: roundTimerConfig.value!,
          undoConfig: undoConfig.value!,
          streakConfig: streakConfig.value!,
          strikeTimerConfig: strikeTimerConfig.value!,
          bonusSlotsConfig: bonusSlotsConfig.value!,
          status: CompletedRunStatus.values.byName(statusName),
          finalScore: finalScore,
          finalFingerprint: finalFingerprint,
          roundsCompleted: roundsCompleted,
          roundsWon: roundsWon,
          roundsLost: roundsLost,
          roundsTimedOut: roundsTimedOut,
          roundsAborted: roundsAborted,
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid completed session result payload: $error',
        ),
      );
    }
  }
}

bool _mapsEqual(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) {
    return false;
  }

  for (final entry in left.entries) {
    if (!right.containsKey(entry.key)) {
      return false;
    }
    if (!_deepEquals(entry.value, right[entry.key])) {
      return false;
    }
  }

  return true;
}

bool _deepEquals(Object? left, Object? right) {
  if (left is Map<String, dynamic> && right is Map<String, dynamic>) {
    return _mapsEqual(left, right);
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!_deepEquals(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

/// Tie-break policy for ordering independent completed runs.
enum CompetitionTieBreakerPolicy {
  score,
  winsThenScore,
  scoreThenFingerprint,
}

/// Ranking configuration for independent run comparison.
final class CompetitionRankingConfig {
  /// Creates a ranking config.
  const CompetitionRankingConfig({
    this.tieBreakerPolicy = CompetitionTieBreakerPolicy.scoreThenFingerprint,
    this.placementBonuses = const <int, int>{},
    this.completionBonus = 0,
  });

  /// Tie-break policy.
  final CompetitionTieBreakerPolicy tieBreakerPolicy;

  /// Optional bonuses by 1-based placement.
  final Map<int, int> placementBonuses;

  /// Bonus applied to completed runs.
  final int completionBonus;
}

/// Breakdown for one ranked completed run.
final class RunComparisonBreakdown {
  /// Creates a comparison breakdown.
  const RunComparisonBreakdown({
    required this.baseScore,
    required this.completionBonus,
    required this.placementBonus,
  });

  /// Base run score from the completed session.
  final int baseScore;

  /// Bonus for completion status.
  final int completionBonus;

  /// Bonus by placement.
  final int placementBonus;

  /// Total score after helper adjustments.
  int get totalScore => baseScore + completionBonus + placementBonus;
}

/// Ranked output for one independent run.
final class RankedRunResult {
  /// Creates a ranked run result.
  const RankedRunResult({
    required this.placement,
    required this.entryId,
    required this.run,
    required this.breakdown,
  });

  /// 1-based placement.
  final int placement;

  /// Caller-supplied neutral entry identifier.
  final String entryId;

  /// Completed run payload.
  final CompletedSessionResult run;

  /// Helper-derived score breakdown.
  final RunComparisonBreakdown breakdown;
}

/// Ordered comparison output for independent runs.
final class CompetitionComparisonResult {
  /// Creates comparison output.
  CompetitionComparisonResult({required List<RankedRunResult> rankings})
      : rankings = List<RankedRunResult>.unmodifiable(rankings);

  /// Ordered rankings from best to worst.
  final List<RankedRunResult> rankings;
}
