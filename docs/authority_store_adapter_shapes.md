# Authority Store Adapter Shapes (No External Dependencies)

Last updated: 2026-02-21

This file provides implementation shapes for production adapters while keeping
the engine package dependency-free.

## AuthorityStorePort Contract

```dart
abstract interface class AuthorityStorePort {
  Future<void> appendAcceptedEvent(
    String matchId,
    PersistedAuthorityEvent event,
  );

  Future<List<PersistedAuthorityEvent>> loadAcceptedEventsAfter(
    String matchId,
    int seqExclusive,
  );

  Future<void> saveSnapshot(
    String matchId,
    PersistedAuthoritySnapshot snapshot,
  );

  Future<PersistedAuthoritySnapshot?> loadLatestSnapshot(String matchId);
}
```

## Relational (SQL) Shape

### Suggested tables

`authority_accepted_events`

- `match_id TEXT NOT NULL`
- `authoritative_sequence INTEGER NOT NULL`
- `engine_version INTEGER NOT NULL`
- `payload_json TEXT NOT NULL`
- `PRIMARY KEY (match_id, authoritative_sequence)`
- `UNIQUE (match_id, player_id, client_event_id)` (optional but recommended)

`authority_snapshots`

- `match_id TEXT PRIMARY KEY`
- `authoritative_sequence INTEGER NOT NULL`
- `engine_version INTEGER NOT NULL`
- `payload_json TEXT NOT NULL`
- `updated_at_unix_ms INTEGER NOT NULL`

### Suggested adapter logic

`appendAcceptedEvent`:

1. Validate sequence monotonicity at storage boundary.
2. Insert event row in one write.
3. Enforce uniqueness constraints if enabled.

`loadAcceptedEventsAfter`:

1. Query `WHERE match_id = ? AND authoritative_sequence > ?`.
2. `ORDER BY authoritative_sequence ASC`.
3. Decode every row into `PersistedAuthorityEvent`.

`saveSnapshot`:

1. Upsert one row by `match_id`.
2. Replace snapshot payload atomically.

`loadLatestSnapshot`:

1. Select snapshot row by `match_id`.
2. Decode into `PersistedAuthoritySnapshot`.

## KV / Document Store Shape

Use two key spaces:

- `authority:{matchId}:events:{seq}` -> event payload JSON
- `authority:{matchId}:snapshot` -> snapshot payload JSON

And one ordered index:

- `authority:{matchId}:event_seqs` -> sorted integer sequences

### Suggested adapter logic

`appendAcceptedEvent`:

1. Write event payload at key including sequence.
2. Add sequence to sorted index.
3. Ensure atomicity (transaction/pipeline/CAS).

`loadAcceptedEventsAfter`:

1. Fetch sequences `> seqExclusive` from sorted index.
2. Load corresponding event keys.
3. Decode and sort by sequence ascending.

`saveSnapshot`:

1. Set snapshot key to latest snapshot payload.

`loadLatestSnapshot`:

1. Get snapshot key and decode.

## Write Ordering Invariant (Host + Adapter)

The runtime contract requires:

1. Reducer computes accepted transition.
2. Adapter durably appends accepted event.
3. Runtime commits in-memory state and returns accepted.

Adapter failures in step 2 must propagate; runtime must not return accepted.

## Recommended Data Integrity Checks in Adapters

- Reject mismatched `matchId` in nested payloads.
- Reject non-accepted `PersistedAuthorityEvent.serverRecord`.
- Verify `authoritativeSequence` continuity on reads where feasible.
- Keep reads deterministic: always return events sorted ascending by sequence.

## Adapter Acceptance Checklist

Before shipping an adapter implementation, verify:

- Deterministic read order (`authoritativeSequence ASC`) is guaranteed.
- Atomicity of accepted-event append is guaranteed.
- Snapshot upsert/update is atomic for a match id.
- Decode failures are surfaced to runtime as hard failures.
- Mismatched match ids and invalid payload types are rejected.
- Load-after-sequence semantics are strict (`>` not `>=`).
- Integration tests cover restore with:
  - valid snapshot + valid tail
  - invalid snapshot fallback to baseline
  - continuity gap failure
