# Celestial TriPeaks

A deterministic, pure Dart TriPeaks engine designed for local play,
replay, and multiplayer authority-hosted integrations.

## What This Project Is

- A pure state machine for TriPeaks mechanics and session progression.
- Deterministic reducers and serialization contracts.
- Multiplayer match and authority runtime orchestration primitives.
- A reference CLI for manual simulation and workflow validation.

## Determinism Guarantees

- Core reducers are pure and deterministic for the same input state,
  action, and configuration.
- Serialization uses explicit versioned envelopes (`schemaVersion` and
  `type`) for state and action payloads.
- Persistence and restore for authority runtime use strict
  sequence-continuity checks.
- Fingerprint helpers provide stable state integrity checks across
  save/replay/authority flows.

See `/docs/architecture_overview.md` and
`/docs/serialization_and_versioning.md`.

## Quick Start

### Prerequisites

- Dart SDK `^3.3.0`

### Install Dependencies

```bash
dart pub get
```

### Run Tests

```bash
dart test
```

### Run Reference CLI

```bash
dart run bin/tripeaks_cli.dart
```

### Useful CLI Examples

```bash
# Fixed seed, six rounds, custom invalid penalty
dart run bin/tripeaks_cli.dart 42 --rounds=6 --invalid-penalty=-3

# Enable rank adjustments for match scoring
dart run bin/tripeaks_cli.dart \
  --first-finish-bonus=5 \
  --rank-adjustments=1:10,2:4,3:0
```

Inside CLI, use `help` for all commands and aliases.

## Main API Entrypoint

- Library export surface:
  `lib/tripeaks_engine.dart`

## Documentation Index

- Full map: `/docs/INDEX.md`
- Architecture: `/docs/architecture_overview.md`
- Engine API usage: `/docs/engine_api_guide.md`
- Serialization/versioning: `/docs/serialization_and_versioning.md`
- Authority integration: `/docs/authority_runtime_integration.md`
- CLI reference: `/docs/cli_reference.md`
- Config tuning: `/docs/configuration_tuning_reference.md`
- Testing strategy: `/docs/testing_strategy.md`

## Stability and Versioning

- Current package version: `0.1.0`.
- Public payloads are versioned and type-tagged.
- Backward compatibility is best-effort during `0.x`; breaking changes
  may occur but must include explicit schema/contract migration notes.

See `/CHANGELOG.md` and `/docs/serialization_and_versioning.md`.

## Contributing

- Contributor workflow and PR checklist:
  `/CONTRIBUTING.md`
