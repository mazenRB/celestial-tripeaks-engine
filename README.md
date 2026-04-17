# Celestial TriPeaks (Pure Dart Engine)

A deterministic, pure Dart Solitaire TriPeaks engine with replay and validation
support.

This package is intentionally scoped to one independently played run at a time.
It owns game rules, deterministic session progression, replay/save integrity,
and optional neutral helpers for comparing finished runs. It does not own rooms,
lobbies, authority runtimes, networking, or backend orchestration.

## Public Entry Points

- `package:celestial_tripeaks/tripeaks_engine.dart`
  - core round/session engine
  - configs, presets, daily helpers, deal policy, hints
- `package:celestial_tripeaks/tripeaks_replay.dart`
  - replay logging, reconstruction, save/load envelopes
- `package:celestial_tripeaks/tripeaks_helpers.dart`
  - neutral completed-run result objects
  - deterministic post-run comparison and helper scoring

## Features

- Classic TriPeaks core mechanics
- Configurable multi-round sessions
- Deterministic seeds and daily challenge helpers
- Replay logging and replay-to-state verification
- Versioned serialization and typed decode failures
- Stable state/session/replay fingerprints
- Optional helper layer for comparing independent finished runs

## Quick Start

```bash
dart pub get
dart test
```

## Engine Usage

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
    tick: 1,
  );

  session = result.state;
  print(session.currentRound.scoreState.totalScore);
}
```

## Replay Usage

```dart
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

  replay = recorded.replay;
  session = recorded.state;
  print(replayFingerprint(replay));
  print(sessionFingerprint(session));
}
```

## Helper Usage

```dart
import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_helpers.dart';

void main() {
  final session = TriPeaksSessionState.newSession(
    ruleset: TriPeaksRuleset.threeRounds,
    seed: 42,
  );
  final result = CompletedSessionResult.fromSession(session);

  final comparison = compareCompletedRuns(
    <String, CompletedSessionResult>{'player-a': result},
  );

  print(comparison.rankings.first.entryId);
}
```

## Architectural Boundary

Engine responsibilities:

- deterministic TriPeaks rules and reducers
- deterministic seeds, presets, and validation
- replay/save envelopes and fingerprinting
- neutral completed-run helper utilities

App or backend responsibilities:

- room handling and seed distribution
- presence, transport, and matchmaking
- result submission and leaderboard flow
- tournament or multiplayer orchestration

## Determinism Contract

Same inputs produce the same outputs. Deterministic inputs are the seed, the
ordered action sequence, and the configs that affect behavior.

Not used inside engine logic:

- `DateTime.now()`
- live timers
- unseeded randomness
- transport or platform state

See [docs/DETERMINISM.md](docs/DETERMINISM.md).
