# Architecture Overview

Last updated: 2026-02-21

## Design Goal

Celestial TriPeaks is structured as a deterministic game engine that can be
embedded in local applications, backend services, and authoritative
multiplayer hosts.

Public package layers:

- `tripeaks_engine.dart` for mechanics, sessions, presets, and helpers
- `tripeaks_replay.dart` for replay/save flows
- `tripeaks_multiplayer.dart` for room foundation and live match orchestration
- `tripeaks_authority.dart` for host/runtime authority flows

## Layering Boundaries

### 1) Mechanics Layer (Pure State Machine)

- Round mechanics and reducers.
- Session progression reducers.
- Match-scoring reducers.
- Room foundation reducer/event processing.
- Live match reducer/event processing.

Core properties:

- No UI/IO dependencies.
- Deterministic transitions.
- Typed failure/result contracts for non-throwing flows.

Primary files:

- `lib/src/round_state.dart`
- `lib/src/round_reducer.dart`
- `lib/src/session_state.dart`
- `lib/src/session_reducer.dart`
- `lib/src/match_scoring_types.dart`
- `lib/src/match_scoring_reducer.dart`
- `lib/src/room.dart`
- `lib/src/match_room.dart`

### 2) Orchestration Layer

- Authority runtime lifecycle around pure reducers.
- Snapshot and accepted-event orchestration.
- Duplicate suppression and replay-based restore.

Primary files:

- `lib/src/authority_runtime.dart`
- `lib/src/authority_runtime_config.dart`
- `lib/src/authority_runtime_errors.dart`

### 3) IO Boundary Layer

- Abstract persistence port for accepted events and snapshots.
- In-memory reference adapter for tests/local use.

Primary files:

- `lib/src/authority_ports.dart`
- `lib/src/authority_store_memory.dart`

### 4) Presentation / Harness Layer

- Reference CLI for scenario validation and manual flow testing.

Primary file:

- `bin/tripeaks_cli.dart`

## Determinism Contract

The engine expects the following to hold:

- Same input state + action + config => same resulting state.
- Numeric game rules are config-driven rather than hardcoded in reducer
  behavior.
- All externally exchanged state/action payloads are serializable and
  versioned.
- Restore from snapshot + accepted tail events is strict and gap-free.

## State-Machine Invariants

- `authoritativeSequence` starts at `0` baseline for match authority state.
- Accepted authoritative events increment sequence by exactly `1`.
- Restore fails on decode or continuity violations for accepted tails.
- Reducer behavior must not depend on wall clock or external randomness.

## Extension Points (Preferred)

- Tune behavior through config objects:
  - `ScoreConfig`
  - `RoundRulesConfig`
  - `UndoConfig`
  - `StreakConfig`
  - `StrikeTimerConfig`
  - `BonusSlotsConfig`
  - `DealPolicyConfig`
  - `MatchScoreConfig`
  - `AuthorityRuntimeConfig`
- Add orchestration logic by composing around existing reducer contracts,
  not by adding host/IO behavior into core reducer files.
- Keep room scope narrow: deterministic bootstrap only, never lobby product
  concerns such as invites, moderation, discovery, presence, notifications,
  transport, or backend-specific schemas.

## Anti-Patterns

- Introducing IO/network/file calls into reducers.
- Bypassing typed decode/encode contracts for public payloads.
- Storing unversioned payloads in authority logs/snapshots.
- Returning accepted authority result before durable append succeeds.

## Known Ambiguities

- None currently identified during docs pass.
