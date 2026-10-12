import 'dart:convert';

import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

/// Failure categories for multiplayer replay verification.
enum MatchSubmissionFailureCode {
  invalidMatchConfig,
  playerNotFound,
  seedMismatch,
  rulesMismatch,
  replayInvalid,
  sessionIncomplete,
}

/// Describes why a submitted multiplayer replay was rejected.
final class MatchSubmissionFailure {
  /// Creates a verification failure.
  const MatchSubmissionFailure({required this.code, required this.message});

  /// Stable failure category.
  final MatchSubmissionFailureCode code;

  /// Human-readable diagnostic for the integrating authority.
  final String message;
}

/// A verified result recomputed from a complete player replay.
final class VerifiedMatchSubmission {
  /// Creates a verified result.
  const VerifiedMatchSubmission({
    required this.playerId,
    required this.finalScore,
    required this.finalFingerprint,
    required this.roundScores,
  });

  /// Participant whose replay was verified.
  final String playerId;

  /// Final score recomputed by the engine.
  final int finalScore;

  /// Deterministic fingerprint of the recomputed session.
  final String finalFingerprint;

  /// Scores for completed rounds in round order.
  final List<int> roundScores;
}

/// Result of validating and reconstructing a multiplayer submission.
final class MatchSubmissionVerification {
  /// Creates a verification result.
  const MatchSubmissionVerification({this.result, this.failure});

  /// Verified result, present when [isValid] is true.
  final VerifiedMatchSubmission? result;

  /// Failure details, present when [isValid] is false.
  final MatchSubmissionFailure? failure;

  /// Whether the submitted replay was accepted.
  bool get isValid => result != null;
}

/// Replays a submission and checks its seed, rules, and completion state.
MatchSubmissionVerification verifyMatchSubmission({
  required MatchConfig config,
  required String playerId,
  required ReplaySession replay,
}) {
  if (!config.playerIds.contains(playerId)) {
    return _reject(
      MatchSubmissionFailureCode.playerNotFound,
      'Player is not part of this match.',
    );
  }
  late final MatchState baseline;
  try {
    baseline = MatchState.newMatch(config: config);
  } on Object catch (error) {
    return _reject(
      MatchSubmissionFailureCode.invalidMatchConfig,
      'Match configuration is invalid: $error',
    );
  }
  final expectedSession = baseline.players.first.session;
  if (replay.seed != expectedSession.seed) {
    return _reject(
      MatchSubmissionFailureCode.seedMismatch,
      'Replay seed does not match the shared match deal.',
    );
  }
  if (!_sameMap(replay.ruleset.toMap(), config.ruleset.toMap()) ||
      !_sameMap(replay.scoreConfig.toMap(), config.scoreConfig.toMap()) ||
      !_sameMap(
        replay.roundRulesConfig.toMap(),
        config.roundRulesConfig.toMap(),
      ) ||
      !_sameMap(
          replay.roundTimerConfig.toMap(), config.roundTimerConfig.toMap()) ||
      !_sameMap(replay.undoConfig.toMap(), config.undoConfig.toMap()) ||
      !_sameMap(replay.streakConfig.toMap(), config.streakConfig.toMap()) ||
      !_sameMap(
          replay.strikeTimerConfig.toMap(), config.strikeTimerConfig.toMap()) ||
      !_sameMap(
          replay.bonusSlotsConfig.toMap(), config.bonusSlotsConfig.toMap())) {
    return _reject(
      MatchSubmissionFailureCode.rulesMismatch,
      'Replay rules do not match this match.',
    );
  }
  late final TriPeaksSessionState session;
  try {
    session = replayToState(replay);
  } on Object catch (error) {
    return _reject(
      MatchSubmissionFailureCode.replayInvalid,
      'Replay could not be reconstructed: $error',
    );
  }
  if (!session.isSessionFinished) {
    return _reject(
      MatchSubmissionFailureCode.sessionIncomplete,
      'Submitted session is not complete.',
    );
  }
  return MatchSubmissionVerification(
    result: VerifiedMatchSubmission(
      playerId: playerId,
      finalScore: session.cumulativeFinishedRoundsScoreTotal,
      finalFingerprint: sessionFingerprint(session),
      roundScores: List<int>.unmodifiable(
        session.roundResults.map((round) => round.finalScore ?? 0),
      ),
    ),
  );
}

MatchSubmissionVerification _reject(
  MatchSubmissionFailureCode code,
  String message,
) {
  return MatchSubmissionVerification(
    failure: MatchSubmissionFailure(code: code, message: message),
  );
}

bool _sameMap(Map<String, dynamic> left, Map<String, dynamic> right) {
  return jsonEncode(left) == jsonEncode(right);
}
