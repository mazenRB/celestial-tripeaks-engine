# Release Readiness Checklist

This checklist is the minimum bar before publishing a release.

## CI gates (must be green)

- `dart format --output=none --set-exit-if-changed .`
- `dart analyze`
- `dart test`
- tag version matches `pubspec.yaml`
- `CHANGELOG.md` contains a matching release section
- `dart pub publish --dry-run` passes in the release validation tree

## Determinism and compatibility checks

- Fingerprint golden test is unchanged unless a deliberate schema/version bump is made.
- Serialization golden tests pass for:
  - `BonusSlotsConfig` (including spawn policy and tier anchors)
  - anchor card DTO (`CardKind.anchor`)
  - replay map config payload
- Replay reconstruction tests pass:
  - live state and replayed state produce identical final fingerprints
- Save/load integrity tests pass:
  - decode recomputes and verifies fingerprint
  - corruption returns typed `corruptSave`
  - unsupported version returns typed failure

## Versioning discipline

- Any payload shape change requires one of:
  - additive backward-compatible decode path, or
  - schema version increment + migration plan
- No use of Dart `hashCode` for wire formats, replay determinism, or fingerprints.

## Pre-release smoke run (manual)

Run CLI with intended flags and verify:

- `fingerprint` command is stable across replay/load cycles
- `replay save` / `replay load` round-trip reproduces state
- bonus slots and undo behavior match expectations

Example:

```bash
dart run bin/tripeaks_cli.dart --rounds=3 --bonus-spawn-policy=tier-fixed-rank
```
