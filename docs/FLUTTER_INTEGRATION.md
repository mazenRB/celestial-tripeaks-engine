# Flutter Integration Guide (Beginner Friendly)

This engine is pure Dart, so Flutter uses it as a domain layer.

## Goal

Keep UI code in Flutter widgets, and keep game rules in this engine.

## 1) Add dependency

If this package is local for now, use a path dependency in your Flutter app:

```yaml
dependencies:
  celestial_tripeaks:
    path: ../Celestial Tripeaks
```

Then run:

```bash
flutter pub get
```

## 2) Create a small controller (ChangeNotifier)

```dart
import 'package:flutter/foundation.dart';
import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_replay.dart';

class TriPeaksController extends ChangeNotifier {
  TriPeaksController() {
    _session = TriPeaksSessionState.newSession(
      ruleset: TriPeaksRuleset.threeRounds,
      seed: 42,
      bonusSlotsConfig: const BonusSlotsConfig(
        spawnPolicy: BonusSlotSpawnPolicy.tierFixedRank,
      ),
    );

    _replay = TriPeaksReplay.newSession(
      seed: _session.seed ?? TriPeaksSessionState.defaultSeed,
      ruleset: _session.ruleset,
      scoreConfig: _session.scoreConfig,
      roundRulesConfig: _session.roundRulesConfig,
      undoConfig: _session.undoConfig,
      streakConfig: _session.streakConfig,
      strikeTimerConfig: _session.strikeTimerConfig,
      bonusSlotsConfig: _session.bonusSlotsConfig,
    );
  }

  late TriPeaksSessionState _session;
  late TriPeaksReplay _replay;
  int _tick = 0;

  TriPeaksSessionState get session => _session;
  TriPeaksState get round => _session.currentRound;

  String get sessionFp => sessionFingerprint(_session);
  String get replayFp => replayFingerprint(_replay);

  void take(int index, {int? targetSlot}) {
    _dispatch(
      PlayRoundAction(RemoveTableauCardAction(index, targetSlot: targetSlot)),
    );
  }

  void draw() {
    _dispatch(const PlayRoundAction(DrawFromStockAction()));
  }

  void undo() {
    _dispatch(const PlayRoundAction(UndoAction()));
  }

  void nextRound() {
    _dispatch(const StartNextRoundAction());
  }

  void autoStep() {
    if (_session.isCurrentRoundFinished && !_session.isSessionFinished) {
      nextRound();
      return;
    }
    final hint = getHint(round, _session.roundRulesConfig, const HintConfig());
    if (hint.isSuccess) {
      take(hint.moveIndex!);
    } else if (round.canDrawFromStock) {
      draw();
    }
  }

  void _dispatch(TriPeaksSessionAction action) {
    final recorded = recordAction(_replay, _session, action, tick: ++_tick);
    _replay = recorded.replay;
    _session = recorded.state;
    notifyListeners();
  }
}
```

## 3) Use controller in UI

Minimal approach without extra packages:

```dart
import 'package:flutter/material.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final TriPeaksController controller;

  @override
  void initState() {
    super.initState();
    controller = TriPeaksController();
    controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = controller.round;
    return Scaffold(
      appBar: AppBar(title: const Text('TriPeaks')),
      body: Column(
        children: [
          Text('Score: ${state.scoreState.totalScore}'),
          Text('Streak: ${state.streakState.currentStreak}'),
          Text('Verify: ${controller.sessionFp == controller.replayFp}'),
          Row(
            children: [
              ElevatedButton(onPressed: controller.draw, child: const Text('Draw')),
              ElevatedButton(onPressed: controller.undo, child: const Text('Undo')),
              ElevatedButton(onPressed: controller.autoStep, child: const Text('Auto')),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 4) Production tips

- Keep all game changes through one dispatch path.
- Pass explicit logical ticks (`tick`) for deterministic streak/timer behavior.
- Persist replay and/or save envelope for recovery.
- On resume, verify fingerprints before trusting client state.
- Do not run game logic directly in widgets.

## 5) Common beginner mistakes

- Updating UI state without dispatching engine actions.
- Using real time (`DateTime.now`) to influence core game state.
- Forgetting to record replay entries when applying actions.
- Treating invalid actions as exceptions (they are typed failures/results).
