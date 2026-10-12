# Celestial TriPeaks Engine

A pure Dart TriPeaks engine with deterministic game rules, multi-round sessions,
replay verification, and optional multiplayer state reducers. It contains no
Flutter or UI dependencies.

## Public Entry Points

- `tripeaks_engine.dart` — core round and session rules, presets, timers, and
  deterministic game data.
- `tripeaks_replay.dart` — replay recording, reconstruction, and save/load.
- `tripeaks_helpers.dart` — completed-run comparison and neutral score helpers.
- `tripeaks_multiplayer.dart` — optional rooms, Async 1v1 matches, and Live
  round coordination.
- `tripeaks_authority.dart` — replay-based verification of player submissions.

The multiplayer entry points are opt-in. Importing the core engine does not
require consumers to use room or match orchestration.

## Multiplayer Model

Each participant plays an independent game with the match's shared seed and
rules. Async is a full-match 1v1. Live rooms wait for every player to finish the
current round, then start a configurable intermission and advance together.
Live uses the engine's existing per-round timer configuration. Apps and
backends provide networking, identity, storage, notifications, and host-driven
clock events.

See [the multiplayer API guide](docs/multiplayer_api.md) for lifecycle details,
configuration examples, and authority boundaries.

## Quick Start

```bash
dart pub get
dart test
```

## Single-Player Usage

```dart
import 'package:celestial_tripeaks/tripeaks_engine.dart';

void main() {
  var session = TriPeaksSessionState.newSession(
    ruleset: TriPeaksRuleset.threeRounds,
    seed: 42,
  );
  final result = tryReduceTriPeaksSession(
    session,
    const PlayRoundAction(DrawFromStockAction()),
  );
  session = result.state;
  print(session.currentRound.scoreState.totalScore);
}
```

## Determinism Contract

Same seed, state, actions, and configuration produce the same game data. The
engine does not read wall-clock time, use transport state, or generate
unseeded randomness. Timer progress and expiry enter as explicit actions.

See [docs/DETERMINISM.md](docs/DETERMINISM.md) and
[docs/multiplayer_api.md](docs/multiplayer_api.md).
