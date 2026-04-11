# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [1.0.0-beta.3] - 2026-04-11

### Changed

- Package surface is now layered into supported entrypoints:
  - `tripeaks_engine.dart` for core engine flows
  - `tripeaks_replay.dart` for replay/save helpers
  - `tripeaks_multiplayer.dart` for match orchestration
  - `tripeaks_authority.dart` for authority/runtime contracts
- Internal engine implementation now lives behind a dedicated `src`
  umbrella library so public exports can be curated without changing engine
  behavior.

### Documentation

- Added entrypoint guidance and import examples for core, replay,
  multiplayer, and authority consumers.

### Quality

- Fixed the CI formatting drift in `session_state_decode.dart`.
- Added a tagged release workflow with strict version, changelog, and
  package dry-run validation for private GitHub releases.
- Added package-release metadata, proprietary license notice, and a minimal
  example for future pub-quality packaging readiness.

## [1.0.0-beta.2] - 2026-03-26

### Added

- Round/session cumulative score helpers:
  - `cumulativeFinishedRoundsScoreTotal`
  - `cumulativeIncludingCurrentRoundScoreTotal`
- `RoundResult.finalScore` persisted on round completion (nullable for backward decode compatibility).
- Deterministic bonus-slot helper `actionableBonusSlotIndices`.
- Deterministic random anchor-rank policy support:
  - `BonusSlotSpawnPolicy.tierRandomRank`
  - replay-safe anchor rank selection and nonce tracking.
- Bonus-slot stock-consume spawn policy:
  - `BonusSlotSpawnPolicy.stockTopCard`
  - slot-open consumes `stock.first` deterministically.
- Time-bonus multiplier mode with host-driven deterministic expiry action.
- Round-based base-point growth configuration (compounding, floor each step).
- Stock-size progression configuration with layout-aware validation.
- Engine-owned mode packaging:
  - `TriPeaksModePreset`
  - `TriPeaksModeBundle`
  - preset-backed daily constructors/helpers.
- Standard single-round ruleset preset support (`TriPeaksRuleset.oneRound`).

### Changed

- `classic` preset now represents standard single-round solitaire profile while preserving celestial score magnitudes.
- `celestial` preset is centralized in engine catalog and now uses `BonusSlotSpawnPolicy.stockTopCard`.
- Public score surfaces now expose component-level breakdown and applied multiplier on both state/result.

### Compatibility

- Additive API changes only; decode paths remain backward-compatible for legacy payloads.
- Preset bundle decode preserves serialized nested config values without re-resolving against current catalog.

### Quality

- Expanded deterministic and replay-parity coverage across scoring, presets, bonus slots, authority runtime, serialization, and save/load.
- Refactored oversized engine/test modules into focused files with unchanged behavior validated by full analyze/test gates.

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
