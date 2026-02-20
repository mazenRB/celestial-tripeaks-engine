import 'dart:convert';
import 'dart:io';

import 'package:celestial_tripeaks/tripeaks_engine.dart';

void main(List<String> args) {
  final config = _parseArgs(args);
  var session = TriPeaksSessionState.newSession(
    ruleset: config.ruleset,
    seed: config.seed,
    scoreConfig: config.roundScoreConfig,
    roundRulesConfig: config.roundRulesConfig,
    undoConfig: config.undoConfig,
    streakConfig: config.streakConfig,
  );
  var matchScore = MatchScoreState(config: config.matchScoreConfig);
  var replay = TriPeaksReplay.newSession(
    seed: session.seed ?? TriPeaksSessionState.defaultSeed,
    ruleset: session.ruleset,
    scoreConfig: session.scoreConfig,
    roundRulesConfig: session.roundRulesConfig,
    undoConfig: session.undoConfig,
    streakConfig: session.streakConfig,
  );
  var actionTick = 0;

  stdout.writeln('Classic TriPeaks CLI');
  stdout.writeln('Rounds per game: ${session.ruleset.roundsPerGame}');
  stdout.writeln('Type "help" for commands.');
  _printBoard(session);

  while (true) {
    stdout.write('\n> ');
    final input = stdin.readLineSync();
    if (input == null) {
      stdout.writeln('Exiting.');
      return;
    }

    final tokens = input.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first.isEmpty) {
      continue;
    }
    final command = tokens.first.toLowerCase();

    if (command == 'quit' || command == 'exit') {
      stdout.writeln('Exiting.');
      return;
    }

    if (command == 'help') {
      _printHelp();
      continue;
    }

    if (command == 'show') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: show');
        continue;
      }
      _printBoard(session);
      continue;
    }

    if (command == 'moves') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: moves');
        continue;
      }
      _printMoves(session.currentRound);
      continue;
    }

    if (command == 'hint') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: hint');
        continue;
      }
      final hint = getHint(
        session.currentRound,
        session.roundRulesConfig,
        config.hintConfig,
      );
      if (!hint.isSuccess) {
        stdout.writeln('Hint unavailable: ${hint.error!.message}');
      } else {
        stdout.writeln('Hint: take ${hint.moveIndex}');
      }
      continue;
    }

    if (command == 'score') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: score');
        continue;
      }
      _printRoundScore(session.currentRound);
      continue;
    }

    if (command == 'draw') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: draw');
        continue;
      }
      final recorded = recordAction(
        replay,
        session,
        const PlayRoundAction(DrawFromStockAction()),
        tick: ++actionTick,
      );
      replay = recorded.replay;
      session = _handleSessionResult(session, recorded.reduceResult);
      continue;
    }

    if (command == 'new') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: new');
        continue;
      }
      session = TriPeaksSessionState.newSession(
        ruleset: config.ruleset,
        seed: config.seed,
        scoreConfig: config.roundScoreConfig,
        roundRulesConfig: config.roundRulesConfig,
        undoConfig: config.undoConfig,
        streakConfig: config.streakConfig,
      );
      replay = TriPeaksReplay.newSession(
        seed: session.seed ?? TriPeaksSessionState.defaultSeed,
        ruleset: session.ruleset,
        scoreConfig: session.scoreConfig,
        roundRulesConfig: session.roundRulesConfig,
        undoConfig: session.undoConfig,
        streakConfig: session.streakConfig,
      );
      actionTick = 0;
      stdout.writeln('Started a new game session.');
      _printBoard(session);
      continue;
    }

    if (command == 'next') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: next');
        continue;
      }
      final recorded = recordAction(
        replay,
        session,
        const StartNextRoundAction(),
        tick: ++actionTick,
      );
      replay = recorded.replay;
      session = _handleSessionResult(session, recorded.reduceResult);
      continue;
    }

    if (command == 'undo') {
      if (tokens.length != 1) {
        stdout.writeln('Usage: undo');
        continue;
      }
      final recorded = recordAction(
        replay,
        session,
        const PlayRoundAction(UndoAction()),
        tick: ++actionTick,
      );
      replay = recorded.replay;
      session = _handleSessionResult(session, recorded.reduceResult);
      continue;
    }

    if (command == 'abort') {
      if (tokens.length > 2) {
        stdout.writeln('Usage: abort [skip|quit|timeout|disconnect]');
        continue;
      }
      final reason = _parseAbortReason(tokens.length == 2 ? tokens[1] : null);
      if (reason == null) {
        stdout.writeln(
          'Invalid abort reason. Use: skip | quit | timeout | disconnect.',
        );
        continue;
      }
      final recorded = recordAction(
        replay,
        session,
        AbortRoundAction(reason: reason),
        tick: ++actionTick,
      );
      replay = recorded.replay;
      session = _handleSessionResult(session, recorded.reduceResult);
      continue;
    }

    if (command == 'take') {
      if (tokens.length != 2) {
        stdout.writeln('Usage: take <index>');
        continue;
      }
      final index = int.tryParse(tokens[1]);
      if (index == null) {
        stdout.writeln('Invalid index. Usage: take <index>');
        continue;
      }
      final recorded = recordAction(
        replay,
        session,
        PlayRoundAction(RemoveTableauCardAction(index)),
        tick: ++actionTick,
      );
      replay = recorded.replay;
      session = _handleSessionResult(session, recorded.reduceResult);
      continue;
    }

    if (command == 'replay') {
      if (tokens.length < 2) {
        stdout.writeln('Usage: replay <show|save|load|step> ...');
        continue;
      }
      final sub = tokens[1].toLowerCase();
      switch (sub) {
        case 'show':
          if (tokens.length != 2) {
            stdout.writeln('Usage: replay show');
            break;
          }
          _printReplay(replay);
          break;

        case 'save':
          if (tokens.length != 3) {
            stdout.writeln('Usage: replay save <file>');
            break;
          }
          final file = File(tokens[2]);
          file.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(replay.toMap()),
          );
          stdout.writeln('Replay saved to ${file.path}');
          break;

        case 'load':
          if (tokens.length != 3) {
            stdout.writeln('Usage: replay load <file>');
            break;
          }
          try {
            final file = File(tokens[2]);
            final text = file.readAsStringSync();
            final decoded = jsonDecode(text);
            if (decoded is! Map<String, dynamic>) {
              stdout.writeln('Invalid replay JSON root.');
              break;
            }
            final decodedReplay = ReplaySession.tryFromMap(decoded);
            if (!decodedReplay.isSuccess) {
              stdout.writeln(
                'Failed to decode replay: ${decodedReplay.error!.message}',
              );
              break;
            }
            final loadedReplay = decodedReplay.value!;
            final rebuilt = replayToState(loadedReplay);
            replay = loadedReplay;
            session = rebuilt;
            actionTick = replay.entries.length;
            stdout.writeln(
              'Replay loaded. Actions: ${replay.entries.length}.',
            );
            _printBoard(session);
          } on Object catch (error) {
            stdout.writeln('Failed to load replay: $error');
          }
          break;

        case 'step':
          if (tokens.length != 3) {
            stdout.writeln('Usage: replay step <count>');
            break;
          }
          final count = int.tryParse(tokens[2]);
          if (count == null) {
            stdout.writeln('Invalid count. Usage: replay step <count>');
            break;
          }
          try {
            final stepped = replayStep(
              replay,
              count,
            );
            stdout.writeln('Replay step: $count/${replay.entries.length}');
            _printBoard(stepped);
          } on Object catch (error) {
            stdout.writeln('Failed to replay step: $error');
          }
          break;

        default:
          stdout.writeln('Unknown replay command: $sub');
          stdout.writeln(
            'Use: replay show | replay save | replay load | replay step',
          );
      }
      continue;
    }

    if (command == 'match') {
      if (tokens.length < 2) {
        stdout.writeln(
          'Usage: match <show|commit|bonus|rank|reset> ...',
        );
        continue;
      }
      final sub = tokens[1].toLowerCase();
      switch (sub) {
        case 'show':
          _printMatchScore(matchScore);
          break;

        case 'commit':
          if (tokens.length < 3) {
            stdout.writeln('Usage: match commit <playerId> [roundScore]');
            break;
          }
          final playerId = tokens[2];
          final roundScore = tokens.length > 3
              ? int.tryParse(tokens[3])
              : session.currentRound.scoreState.totalScore;
          if (roundScore == null) {
            stdout
                .writeln('Invalid roundScore. Usage: match commit <id> <int>');
            break;
          }
          matchScore = _reduceMatch(
            matchScore,
            RoundScoreAggregated(playerId: playerId, roundScore: roundScore),
          );
          break;

        case 'bonus':
          if (tokens.length < 3) {
            stdout.writeln('Usage: match bonus <playerId>');
            break;
          }
          matchScore = _reduceMatch(
            matchScore,
            FirstFinishBonusApplied(playerId: tokens[2]),
          );
          break;

        case 'rank':
          if (tokens.length < 4) {
            stdout.writeln('Usage: match rank <playerId> <rank>');
            break;
          }
          final rank = int.tryParse(tokens[3]);
          if (rank == null) {
            stdout.writeln('Invalid rank. Usage: match rank <playerId> <rank>');
            break;
          }
          matchScore = _reduceMatch(
            matchScore,
            RankingAdjustmentApplied(playerId: tokens[2], rank: rank),
          );
          break;

        case 'reset':
          matchScore = MatchScoreState(config: config.matchScoreConfig);
          stdout.writeln('Match score reset.');
          break;

        default:
          stdout.writeln('Unknown match command: $sub');
          stdout.writeln(
            'Use: match show | match commit | match bonus | match rank | match reset',
          );
      }
      continue;
    }

    stdout.writeln('Unknown command: ${tokens.join(' ')}');
    stdout.writeln('Type "help" for commands.');
  }
}

TriPeaksSessionState _handleSessionResult(
  TriPeaksSessionState current,
  TriPeaksSessionReduceResult result,
) {
  if (!result.isSuccess) {
    final message = result.sessionError?.message ?? result.roundError!.message;
    stdout.writeln('Invalid move: $message');
    final next = result.state;
    if (!identical(next, current)) {
      _printBoard(next);
    }
    return next;
  }

  final next = result.state;
  _printBoard(next);

  final roundJustCompleted = next.roundsCompleted > current.roundsCompleted;
  if (roundJustCompleted &&
      next.roundResults.isNotEmpty &&
      next.roundResults.last.outcome == RoundOutcome.aborted) {
    final completed = next.roundResults.last;
    stdout.writeln(
      'Round ${completed.roundNumber}: aborted (${completed.abortReason}).',
    );
  } else if (next.currentRound.isWon) {
    stdout.writeln('Round ${next.currentRoundNumber}: won.');
  } else if (next.currentRound.isLost) {
    stdout.writeln('Round ${next.currentRoundNumber}: lost.');
  }
  if (next.isCurrentRoundFinished && !next.isSessionFinished) {
    stdout
        .writeln('Type "next" to start round ${next.currentRoundNumber + 1}.');
  }
  if (next.isSessionFinished) {
    stdout.writeln(
      'Session finished. Wins: ${next.roundsWon}/${next.ruleset.roundsPerGame}',
    );
  }

  return next;
}

MatchScoreState _reduceMatch(
  MatchScoreState current,
  MatchScoreEvent event,
) {
  final result = tryReduceMatchScore(current, event);
  if (!result.isSuccess) {
    stdout.writeln('Match scoring error: ${result.error!.message}');
    return current;
  }
  _printMatchScore(result.state);
  return result.state;
}

void _printHelp() {
  stdout.writeln('Commands:');
  stdout.writeln('  show                        Show board/session.');
  stdout
      .writeln('  moves                       Show removable tableau indices.');
  stdout.writeln(
      '  hint                        Show deterministic suggested move.');
  stdout.writeln('  score                       Show round score state.');
  stdout.writeln('  draw                        Draw one card from stock.');
  stdout.writeln(
      '  undo                        Undo last successful round action.');
  stdout.writeln(
      '  take <index>                Remove an exposed adjacent card.');
  stdout.writeln(
      '  abort [reason]              Abort round: skip|quit|timeout|disconnect.');
  stdout.writeln(
      '  next                        Start next round after current ends.');
  stdout.writeln('  new                         Start a new game session.');
  stdout.writeln('  match show                  Show match scoring state.');
  stdout.writeln(
      '  match commit <id> [score]   Aggregate round score for player.');
  stdout
      .writeln('  match bonus <id>            Apply first-finish bonus event.');
  stdout
      .writeln('  match rank <id> <rank>      Apply ranking adjustment event.');
  stdout.writeln('  match reset                 Reset match scoring.');
  stdout.writeln('  replay show                Show replay metadata.');
  stdout.writeln('  replay save <file>         Save replay as JSON.');
  stdout
      .writeln('  replay load <file>         Load replay and rebuild session.');
  stdout.writeln('  replay step <count>        Show state after N actions.');
  stdout.writeln('Flags:');
  stdout.writeln('  --wrap-ace-king=true|false  Enable/disable A-K wrapping.');
  stdout.writeln('  --invalid-penalty=<int>     Penalty for invalid move.');
  stdout.writeln('  --undo-enabled=true|false   Enable/disable undo.');
  stdout.writeln('  --undo-max-steps=<int>      Max undo snapshots retained.');
  stdout.writeln('  --hints-enabled=true|false  Enable/disable hints.');
  stdout
      .writeln('  --streak-enabled=true|false Enable/disable streak tracking.');
  stdout.writeln('  --streak-reset-on-draw=...  Reset streak when drawing.');
  stdout
      .writeln('  --streak-reset-on-invalid=... Reset streak on invalid move.');
  stdout.writeln(
      '  --streak-max-gap=<int>      Max tick gap before streak reset.');
  stdout.writeln('  quit                        Exit CLI.');
}

void _printMoves(TriPeaksState state) {
  final moves = state.availableMoves.removableTableauIndices;
  stdout.writeln('Removable: ${moves.isEmpty ? '(none)' : moves.join(', ')}');
  stdout.writeln('Can draw: ${state.canDrawFromStock}');
}

void _printRoundScore(TriPeaksState state) {
  final score = state.scoreState;
  stdout.writeln(
    'Round score: total=${score.totalScore}, '
    'moves=${score.movesCount}, lastDelta=${score.lastDelta}',
  );
}

void _printMatchScore(MatchScoreState state) {
  stdout.writeln('Match scores: ${state.totalScoresByPlayer}');
  stdout.writeln('  Round totals: ${state.roundScoresByPlayer}');
  stdout.writeln('  Bonuses: ${state.multiplayerBonusesByPlayer}');
  stdout.writeln('  Rank adjustments: ${state.competitiveAdjustmentsByPlayer}');
  stdout.writeln(
    '  First finish awarded to: ${state.firstFinishAwardedTo ?? '(none)'}',
  );
  stdout.writeln('  Processed events: ${state.processedEventsCount}');
}

void _printReplay(TriPeaksReplay replay) {
  stdout.writeln(
    'Replay: seed=${replay.seed}, rounds=${replay.ruleset.roundsPerGame}, '
    'entries=${replay.entries.length}, '
    'schema=${replay.schemaVersion}, '
    'engine=${replay.engineVersion}',
  );
  final accepted = replay.entries.where((entry) => entry.accepted).length;
  final rejected = replay.entries.length - accepted;
  stdout.writeln('  accepted=$accepted, rejected=$rejected');
  if (replay.entries.isEmpty) {
    return;
  }
  final start = replay.entries.length > 10 ? replay.entries.length - 10 : 0;
  for (var i = start; i < replay.entries.length; i++) {
    final entry = replay.entries[i];
    final status = entry.accepted
        ? 'ok'
        : 'fail:${entry.failureReason?.name ?? 'unknown'}';
    stdout.writeln(
      '  [${entry.sequence}] ${entry.action.kind.name} '
      'tick=${entry.tick} $status',
    );
  }
}

void _printBoard(TriPeaksSessionState session) {
  final state = session.currentRound;
  stdout.writeln('');
  stdout.writeln(
    'Round: ${session.currentRoundNumber}/${session.ruleset.roundsPerGame}',
  );
  stdout.writeln(
    'Session: ${session.roundsWon}W-${session.roundsLost}L-'
    '${session.roundsAborted}A | Completed: ${session.roundsCompleted}',
  );
  stdout.writeln(
    'Round score: ${state.scoreState.totalScore} '
    '(moves=${state.scoreState.movesCount}, '
    'lastDelta=${state.scoreState.lastDelta})',
  );
  stdout.writeln(
    'Streak: current=${state.streakState.currentStreak}, '
    'best=${state.streakState.bestStreak}, '
    'lastTick=${state.streakState.lastActionTick ?? '(none)'}',
  );
  stdout.writeln('Waste top: ${_cardLabel(state.wasteTop)}');
  stdout.writeln('Stock: ${state.stockCount}');
  stdout.writeln(
    'Round won: ${state.isWon} | Round lost: ${state.isLost}'
    ' | Session finished: ${session.isSessionFinished}',
  );
  stdout.writeln('');

  _printRow(state, 0, 3, leftPad: 12);
  _printRow(state, 3, 6, leftPad: 9);
  _printRow(state, 9, 9, leftPad: 5);
  _printRow(state, 18, 10, leftPad: 0);
}

void _printRow(
  TriPeaksState state,
  int start,
  int length, {
  required int leftPad,
}) {
  final prefix = ' ' * leftPad;
  final cells = <String>[];
  for (var i = start; i < start + length; i++) {
    cells.add('${i.toString().padLeft(2)}:${_cell(state, i)}');
  }
  stdout.writeln('$prefix${cells.join('  ')}');
}

String _cell(TriPeaksState state, int index) {
  if (state.removed[index]) {
    return '--';
  }
  if (!state.isExposed(index)) {
    return '##';
  }
  return _cardLabel(state.tableau[index]);
}

String _cardLabel(Card card) => '${card.rank.label}${_suitSymbol(card.suit)}';

String _suitSymbol(Suit suit) {
  switch (suit) {
    case Suit.clubs:
      return 'C';
    case Suit.diamonds:
      return 'D';
    case Suit.hearts:
      return 'H';
    case Suit.spades:
      return 'S';
  }
}

AbortReason? _parseAbortReason(String? value) {
  if (value == null) {
    return AbortReason.userSkip;
  }
  switch (value.toLowerCase()) {
    case 'skip':
      return AbortReason.userSkip;
    case 'quit':
      return AbortReason.userQuit;
    case 'timeout':
      return AbortReason.timeout;
    case 'disconnect':
      return AbortReason.disconnect;
    default:
      return null;
  }
}

final class _CliConfig {
  const _CliConfig({
    required this.ruleset,
    required this.roundScoreConfig,
    required this.roundRulesConfig,
    required this.undoConfig,
    required this.hintConfig,
    required this.streakConfig,
    required this.matchScoreConfig,
    this.seed,
  });

  final TriPeaksRuleset ruleset;
  final ScoreConfig roundScoreConfig;
  final RoundRulesConfig roundRulesConfig;
  final UndoConfig undoConfig;
  final HintConfig hintConfig;
  final StreakConfig streakConfig;
  final MatchScoreConfig matchScoreConfig;
  final int? seed;
}

_CliConfig _parseArgs(List<String> args) {
  TriPeaksRuleset ruleset = TriPeaksRuleset.threeRounds;
  int? seed;
  int invalidPenalty = 0;
  bool aceKingWrapAround = false;
  bool undoEnabled = true;
  int undoMaxSteps = 10;
  bool hintsEnabled = true;
  bool streakEnabled = true;
  bool streakResetOnDraw = true;
  bool streakResetOnInvalid = false;
  int? streakMaxGap;
  int firstFinishBonus = 0;
  Map<int, int> rankingAdjustments = const <int, int>{};

  for (final arg in args) {
    if (arg.startsWith('--rounds=')) {
      final value = int.tryParse(arg.substring('--rounds='.length));
      ruleset = _rulesetFromRounds(value);
      continue;
    }
    if (arg.startsWith('--first-finish-bonus=')) {
      firstFinishBonus = int.tryParse(
            arg.substring('--first-finish-bonus='.length),
          ) ??
          0;
      continue;
    }
    if (arg.startsWith('--invalid-penalty=')) {
      invalidPenalty = int.tryParse(
            arg.substring('--invalid-penalty='.length),
          ) ??
          0;
      continue;
    }
    if (arg.startsWith('--wrap-ace-king=')) {
      final value = arg.substring('--wrap-ace-king='.length).toLowerCase();
      aceKingWrapAround = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--undo-enabled=')) {
      final value = arg.substring('--undo-enabled='.length).toLowerCase();
      undoEnabled = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--undo-max-steps=')) {
      undoMaxSteps = int.tryParse(arg.substring('--undo-max-steps='.length)) ??
          undoMaxSteps;
      if (undoMaxSteps < 0) {
        undoMaxSteps = 0;
      }
      continue;
    }
    if (arg.startsWith('--hints-enabled=')) {
      final value = arg.substring('--hints-enabled='.length).toLowerCase();
      hintsEnabled = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--streak-enabled=')) {
      final value = arg.substring('--streak-enabled='.length).toLowerCase();
      streakEnabled = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--streak-reset-on-draw=')) {
      final value =
          arg.substring('--streak-reset-on-draw='.length).toLowerCase();
      streakResetOnDraw = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--streak-reset-on-invalid=')) {
      final value =
          arg.substring('--streak-reset-on-invalid='.length).toLowerCase();
      streakResetOnInvalid = value == 'true' || value == '1' || value == 'yes';
      continue;
    }
    if (arg.startsWith('--streak-max-gap=')) {
      streakMaxGap = int.tryParse(arg.substring('--streak-max-gap='.length));
      continue;
    }
    if (arg.startsWith('--rank-adjustments=')) {
      rankingAdjustments = _parseRankingAdjustments(
        arg.substring('--rank-adjustments='.length),
      );
      continue;
    }
    seed ??= int.tryParse(arg);
  }

  return _CliConfig(
    ruleset: ruleset,
    seed: seed,
    roundScoreConfig: ScoreConfig(penaltyInvalidAction: invalidPenalty),
    roundRulesConfig: RoundRulesConfig(
      aceKingWrapAround: aceKingWrapAround,
    ),
    undoConfig: UndoConfig(
      enabled: undoEnabled,
      maxSteps: undoMaxSteps,
    ),
    hintConfig: HintConfig(enabled: hintsEnabled),
    streakConfig: StreakConfig(
      enabled: streakEnabled,
      resetOnDraw: streakResetOnDraw,
      resetOnInvalidAction: streakResetOnInvalid,
      maxGapTicks: streakMaxGap,
    ),
    matchScoreConfig: MatchScoreConfig(
      firstFinishBonus: firstFinishBonus,
      rankingAdjustments: rankingAdjustments,
    ),
  );
}

Map<int, int> _parseRankingAdjustments(String value) {
  if (value.trim().isEmpty) {
    return const <int, int>{};
  }
  final out = <int, int>{};
  final pairs = value.split(',');
  for (final pair in pairs) {
    final parts = pair.split(':');
    if (parts.length != 2) {
      continue;
    }
    final rank = int.tryParse(parts[0].trim());
    final points = int.tryParse(parts[1].trim());
    if (rank != null && points != null) {
      out[rank] = points;
    }
  }
  return Map<int, int>.unmodifiable(out);
}

TriPeaksRuleset _rulesetFromRounds(int? rounds) {
  switch (rounds) {
    case 6:
      return TriPeaksRuleset.sixRounds;
    case 10:
      return TriPeaksRuleset.tenRounds;
    case 3:
    case null:
      return TriPeaksRuleset.threeRounds;
    default:
      stdout.writeln(
        'Invalid rounds value "$rounds". Falling back to 3 rounds.',
      );
      return TriPeaksRuleset.threeRounds;
  }
}
