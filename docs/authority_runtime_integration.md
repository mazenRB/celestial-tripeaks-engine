# Authority Runtime Integration

Last updated: 2026-02-21

## Purpose

`AuthorityRuntime` provides a host-facing orchestration layer that couples
pure match reducers with durable accepted-event logs and periodic snapshots.

## Key Types

- `AuthorityRuntime`
- `AuthorityRuntimeState`
- `AuthorityRequestContext`
- `AuthorityApplyResult`
- `AuthorityRestoreResult`
- `AuthorityRuntimeConfig`
- `AuthorityStorePort`

## Lifecycle

### 1) Bootstrap

- Build baseline `MatchState` for one `matchId`.
- Baseline must have `authoritativeSequence == 0`.
- Construct runtime with store and config.

### 2) Restore on Startup

Call:

```dart
await runtime.restore(matchId)
```

Restore flow:

1. Load latest snapshot from store.
2. Validate snapshot schema, match identity, sequence, and fingerprint.
3. On invalid snapshot, fall back to baseline.
4. Load accepted event tail with `authoritativeSequence > snapshotSeq`.
5. Enforce strict continuity (`S+1`, `S+2`, ...).
6. Replay accepted events deterministically to rebuild runtime state.

### 3) Apply Client Events

For each client event:

- Provide trusted `AuthorityRequestContext` (subject + resolved player id).
- Call runtime apply.
- If accepted:
  - runtime appends accepted event durably through `AuthorityStorePort`
  - runtime updates in-memory state
  - snapshot may be emitted depending on
    `AuthorityRuntimeConfig.snapshotEveryAccepted`

### 4) Reconnect and Resync Behavior

Apply results expose protocol hints:

- `duplicateIgnored`
- `lastAcceptedClientSeq`
- `mustFullyResync`

Hosts should map these to transport-level reconnect/resync actions.

## Durability Ordering Invariant

For accepted outcomes, the following ordering is required:

1. Compute accepted transition.
2. Durably append accepted event.
3. Commit in-memory runtime state and return accepted.

If step 2 fails, runtime must not return accepted.

## Store Port Responsibilities

The adapter must implement:

- `appendAcceptedEvent(...)`
- `loadAcceptedEventsAfter(...)`
- `saveSnapshot(...)`
- `loadLatestSnapshot(...)`

Detailed shapes and adapter guidance:

- `/docs/authority_store_adapter_shapes.md`
- `/docs/authority_runtime_schema.md`

## Runtime Configuration Defaults

From `AuthorityRuntimeConfig`:

- `snapshotEveryAccepted = 100`
- `processedClientEventIdsCapacityPerPlayer = 1000`

## Failure Handling Guidance

- Treat restore decode/continuity failures as startup-blocking until state is
  reconciled.
- Treat apply persistence failures as request failures (not accepted outcomes).
- Log all typed failure codes/messages for observability.

## Known Ambiguities

- None identified in current runtime contract docs.
