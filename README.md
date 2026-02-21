# Celestial TriPeaks (Pure Dart Engine)

A deterministic, pure Dart Solitaire TriPeaks engine (no Flutter imports).

This project is designed so you can:
- build mobile/web/desktop/server apps on top of the same rules engine
- replay and verify games deterministically
- save/load safely with integrity checks
- support single-player and multiplayer orchestration layers

## Who This Is For

- Beginners who want to test TriPeaks logic quickly via CLI
- App developers who want a reusable game engine package
- Backend developers who need deterministic replay/validation

## Features

- Classic TriPeaks core mechanics
- Configurable rounds per session (`3`, `6`, `10`)
- Scoring policies (moves, draws, invalid penalties, peak clear bonuses)
- Undo (bounded, configurable)
- Hint queries (deterministic)
- Streak/combo state with logical ticks (no wall clock dependency)
- Bonus slots (including deterministic tier-fixed anchors)
- Strike timeout integration via explicit expiry action
- Daily challenge deterministic seeding
- Replay/event log (accepted/rejected attempts)
- Stable versioned serialization for state/actions/configs/replay
- Stable state/session/replay fingerprints
- Save/load envelopes with fingerprint integrity validation
- Deal policy with optional solvable-deal requirement
- Multiplayer room/match orchestration and server-authority layer
- Match finalization + competitive scoring policy

## Quick Start (Beginner)

### 1) Install dependencies

```bash
dart pub get
```

### 2) Run tests

```bash
dart test
```

### 3) Start CLI sandbox

```bash
dart run bin/tripeaks_cli.dart --rounds=3 --bonus-spawn-policy=tier-fixed-rank
```

### 4) Use the fastest commands

Inside CLI:
- `auto 20` -> plays 20 deterministic helper steps
- `fp` -> prints round/session/replay fingerprints
- `verify` -> checks that session and replay fingerprints match
- `replay save` -> saves replay to auto-generated file name
- `replay load <file>` -> rebuilds session from replay
- `help` -> full command list

See full CLI tutorial: [docs/CLI_GUIDE.md](docs/CLI_GUIDE.md)

## Minimal Engine Usage (Code)

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

## Determinism Contract

Same inputs => same outputs.

Deterministic inputs are:
- seed
- ordered action/event sequence
- all configs affecting behavior

Not used inside engine logic:
- `DateTime.now()`
- timers
- unseeded randomness
- platform-dependent `hashCode` for determinism decisions

See: [docs/DETERMINISM.md](docs/DETERMINISM.md)

## Stability and Versioning

- DTOs are versioned (`schemaVersion`)
- decode failures are typed (no exceptions for normal decode errors)
- unsupported versions return typed failure unless migrated

Release checklist: [RELEASE_READINESS.md](RELEASE_READINESS.md)

## CI

GitHub Actions workflow at:
- `.github/workflows/ci.yml`

Current gates:
- format check
- static analysis
- test suite

