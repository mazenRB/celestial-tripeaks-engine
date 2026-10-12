# Determinism, Replay, and Integrity

This engine is built around deterministic simulation.

Import guidance:

- `tripeaks_engine.dart` for state/session fingerprints
- `tripeaks_replay.dart` for replay logging and replay fingerprints
- `tripeaks_multiplayer.dart` for deterministic room/match event reducers
- `tripeaks_authority.dart` for replay-based result verification

## Deterministic Inputs

A state transition is fully determined by:
- seed
- current state
- action/event
- configs
- explicit logical tick/sequence where required
- explicit elapsed-time actions for Async deadlines and Live intermissions

## Deterministic Outputs

Given the same inputs above, you get:
- same resulting state
- same replay outcome
- same fingerprints

## Fingerprints

APIs:
- `stateFingerprint(TriPeaksState)`
- `sessionFingerprint(TriPeaksSessionState)`
- `replayFingerprint(ReplaySession, [step])`

Use these for:
- client/server sync checks
- replay verification
- save/load integrity checks

## Replay

Replay stores ordered attempts with acceptance status.

Core APIs:
- `recordAction(replay, state, action, tick: ...)`
- `replayToState(replay)`
- `replayStep(replay, n)`

Properties:
- accepted and rejected attempts are preserved in log
- reconstruction applies accepted entries deterministically

## Save/Load Integrity

Save envelopes include a fingerprint.

On decode:
1. payload is decoded to typed DTO
2. fingerprint is recomputed
3. mismatch => typed `corruptSave` failure

## Serialization Rules

- all payloads include `schemaVersion`
- typed decode failures instead of throwing for normal decode errors
- unsupported versions return typed failure unless migration is added

## What To Avoid in Engine Logic

- no `DateTime.now()`
- no wall-clock timer reads
- no unseeded randomness
- no platform `hashCode` for deterministic decisions
