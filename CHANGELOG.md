# Changelog

All notable changes to this project are documented in this file.

## [1.0.0-beta.1] - 2026-02-20

### Added

- Deterministic pure Dart TriPeaks round and session engine.
- Configurable rounds per game (`3`, `6`, `10`).
- Configurable scoring policy:
  - tableau move points
  - draw points
  - invalid action penalty
  - peak-cleared bonus
- Optional undo with bounded history (`enabled`, `maxSteps`).
- Deterministic hint queries (`getPlayableMoves`, `getHint`).
- Streak/combo state with explicit logical tick support.
- Strike timer expiry action (`StrikeTimerExpiredAction`) with token validation.
- Bonus slots with configurable unlock/close behavior.
- Bonus slot spawn policy support:
  - `joker`
  - `tierFixedRank` (deterministic anchor rank by tier)
- Daily challenge deterministic seed derivation by date/config.
- Replay/event-log support:
  - accepted/rejected action attempts
  - deterministic state reconstruction
  - map/json round-trips
- Versioned DTO serialization for public engine types.
- Stable deterministic fingerprinting:
  - round, session, replay
- Save/load envelopes with fingerprint integrity verification.
- Deal policy mode for random vs solvable-deal selection.
- Multiplayer room/match orchestration primitives:
  - ordered events
  - per-player independent sessions
  - authoritative sequences
  - reconnect/recovery DTOs
- Match scoring/finalization policy layer.
- Server authority module with idempotency/order controls.
- Beginner-friendly CLI with:
  - aliases
  - `play`
  - `auto [steps]`
  - replay save/load/step
  - `fp` and `verify` commands

### Changed

- Default Ace↔King wrapping enabled.
- Default streak reset on invalid action enabled.
- Draw scoring default set to `0`.
- Bonus slot behavior evolved to support deterministic anchor policies.

### Quality

- Expanded automated tests for determinism, replay, serialization, save/load, and bonus-slot behavior.
- Added CI workflow for format/analyze/test gates.
- Added release readiness checklist documentation.

