# Changelog

All notable changes to this project are documented in this file.

## [1.0.0-rc.6] - 2026-10-12

### Added

- Optional versioned room and multiplayer APIs with independent per-player
  sessions and shared-seed matches.
- Async 1v1 deadlines and Live round barriers with configurable intermissions
  and skip votes, reusing existing per-round timer presets.
- Replay-based authority verification and complete/per-round match results.

## [1.0.0-rc.5] - 2026-10-11

### Added

- Reducer results report newly cleared peak IDs and the points awarded for
  each peak.

## [1.0.0-rc.4] - 2026-06-13

### Added

- Exposed `activeMultiplier` getter on `TriPeaksState` (via the `TriPeaksStateQueries` extension) as a single source of truth for the presentation layer.

## [1.0.0-rc.3] - 2026-04-18

### Changed

- Removed `tripeaks_multiplayer.dart` and `tripeaks_authority.dart`.
- Re-centered the package on deterministic single-run gameplay, replay, and
  validation.
- Added `tripeaks_helpers.dart` for neutral completed-run DTOs and optional
  post-run comparison and scoring helpers.
- Removed room, live-match, and authority runtime models, reducers, tests, and
  docs from the engine boundary.

## [1.0.0-rc.2] - 2026-04-14

### Added

- Minimal deterministic room foundation under `tripeaks_multiplayer.dart`:
  - `RoomConfig`
  - `RoomState`
  - `RoomMemberState`
  - `RoomEvent`
  - `RoomReduceResult`
  - `MatchBootstrap`
- Canonical room-to-match bootstrap flow with deterministic host ownership,
  host transfer, and start validation.

### Changed

- Multiplayer architecture is now explicitly split into:
  - room foundation for pre-match deterministic coordination
  - live match state for gameplay
- `MatchState` is now a live-match baseline created from a fixed player roster.
- Authority/runtime flows remain match-scoped and no longer treat join/start
  as live match events.

### Documentation

- Added `docs/room_foundation.md`.
- Clarified that engine-owned room payloads must not absorb invites,
  moderation, discovery, presence, notifications, platform identity, or
  backend-specific schema concerns.

## [1.0.0-rc.1] - 2026-04-11

### Changed

- Promoted the package line from beta to the first release candidate with no
  gameplay or API changes from `1.0.0-beta.4`.

## [1.0.0-beta.4] - 2026-04-11

### Fixed

- Corrected GitHub release note extraction in the private release workflow so
  tagged releases can complete successfully.

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
