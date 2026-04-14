# Testing Strategy

Last updated: 2026-02-21

## Goals

- Preserve deterministic behavior across reducers and orchestration layers.
- Catch schema/contract regressions before integration breakage.
- Provide confidence for replay, save/restore, and authority runtime flows.

## Test Stack

- Unit and integration-style package tests via `package:test`.
- Run with:

```bash
dart test
```

## Deterministic Fixture Rules

- Use explicit seeds in tests whenever randomness is involved.
- Prefer fixed action sequences for replay/session/match tests.
- Assert stable outcomes and fingerprints where relevant.
- Avoid wall-clock timing assumptions in reducer tests.

## Subsystem Test Matrix

### Round Reducer

- Valid action transitions.
- Invalid action failure codes.
- Score delta behavior.
- Undo behavior with enabled/disabled configurations.

### Session Reducer

- Round progression and terminal session behavior.
- Abort flows and typed failure handling.

### Replay

- Record accepted/rejected attempts.
- Rebuild final state from accepted entries only.
- Step replay consistency (`after N actions`).

### Serialization and Save

- `toMap`/`tryFromMap` round-trip coverage.
- Unsupported schema and invalid payload handling.
- Save fingerprint mismatch rejection.

### Match and Match Scoring

- Room host transfer, room start validation, and room bootstrap determinism.
- Live match submit flow constraints.
- Scoring event application and ordering.
- First-finish uniqueness behavior.

### Authority Runtime

- Restore with valid snapshot + tail.
- Invalid snapshot fallback behavior.
- Continuity gap failures.
- Durable append ordering for accepted outcomes.
- Duplicate suppression and `lastAcceptedClientSeq` behavior.

## Regression and Contract Coverage

For each public contract change, add tests for:

- decode success for current version
- decode failure for unsupported version
- invariants tied to sequence/fingerprint integrity
- excluded room fields staying excluded from public payloads

## CI Expectations

Minimum pre-merge checks:

- `dart test`
- Documentation updates for public contract/config changes

## Review Checklist

- Are seeds explicit?
- Are typed errors asserted (not only generic failure)?
- Are versioned payload rules validated?
- Does the test prove deterministic equivalence, not just no-throw?
