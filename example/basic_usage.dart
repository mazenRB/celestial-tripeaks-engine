import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

void main() {
  var session = TriPeaksSessionState.newSession(
    ruleset: TriPeaksRuleset.threeRounds,
    seed: 42,
  );
  var replay = TriPeaksReplay.newSession(
    seed: 42,
    ruleset: TriPeaksRuleset.threeRounds,
  );

  final recorded = recordAction(
    replay,
    session,
    const PlayRoundAction(DrawFromStockAction()),
    tick: 1,
  );

  session = recorded.state;
  replay = recorded.replay;

  print('Score: ${session.currentRound.scoreState.totalScore}');
  print('Replay fingerprint: ${replayFingerprint(replay)}');
}
