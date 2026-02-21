# Authority Runtime Schema (Accepted-Only Log)

Last updated: 2026-02-21

This document defines durable payload shapes for the authority runtime.

## Sequence Model

- `authoritativeSequence` starts at `0` for an empty baseline.
- First accepted event has `authoritativeSequence = 1`.
- Snapshot stores `authoritativeSequence = last applied accepted sequence`.
- `loadAcceptedEventsAfter(matchId, seqExclusive)` returns events with
  `authoritativeSequence > seqExclusive`.
- Restore continuity:
  - with snapshot sequence `S`, first tail event must be `S + 1`
  - each subsequent event increments by exactly `1`

## PersistedAuthorityEvent

Persisted accepted transition only.

```json
{
  "schemaVersion": 1,
  "type": "persisted_authority_event",
  "engineVersion": 1,
  "matchId": "match-123",
  "authoritativeSequence": 42,
  "playerId": "p1",
  "clientSeq": 88,
  "clientEventId": "p1-88",
  "clientEvent": { "...": "ClientEvent.toMap()" },
  "serverRecord": { "...": "ServerEventRecord.toMap(), outcome=accepted" }
}
```

Validation rules:

- `type` must be `persisted_authority_event`.
- `serverRecord.outcome` must be `accepted`.
- `serverRecord.authoritativeSequence` must equal top-level
  `authoritativeSequence`.
- `matchId` must match runtime match id and nested payload match ids.
- Event sequence continuity must be gap-free during restore.

## PersistedAuthoritySnapshot

Checkpoint of runtime state.

```json
{
  "schemaVersion": 1,
  "type": "persisted_authority_snapshot",
  "engineVersion": 1,
  "matchId": "match-123",
  "authoritativeSequence": 100,
  "matchState": { "...": "MatchState.toMap()" },
  "matchFingerprint": "9f17b6a4",
  "recentClientEventIdsByPlayer": {
    "p1": ["p1-80", "p1-81"],
    "p2": ["p2-51"]
  },
  "lastAcceptedClientSeqByPlayer": {
    "p1": 81,
    "p2": 51
  }
}
```

Validation rules:

- `type` must be `persisted_authority_snapshot`.
- `matchId` must match restore target and `matchState.config.matchId`.
- `authoritativeSequence` must equal `matchState.authoritativeSequence`.
- `matchFingerprint` must match recomputed fingerprint of `matchState`.
- `recentClientEventIdsByPlayer` values are string lists.
- `lastAcceptedClientSeqByPlayer` values are integers.

## Restore Rules

1. Load latest snapshot.
2. If snapshot invalid, fall back to baseline (`snapshotSeq = 0`).
3. Load accepted events after `snapshotSeq`.
4. Validate every event decode + match id + strict sequence continuity.
5. Fail restore on tail decode/continuity errors (no partial restore).
6. Replay accepted events deterministically to rebuild state.

## Runtime Apply Invariant

If `apply()` returns `accepted`, the accepted event is already durably appended.
If durable append fails, runtime must fail and must not return accepted.

## Compatibility and Evolution

- Current schema version is `1`.
- During `0.x`, payload compatibility is best-effort and can change.
- Any payload-breaking change must include:
  - updated decoder behavior
  - deterministic fixtures for old/new payloads
  - changelog + docs updates (`INDEX`, serialization, authority docs)

See also:

- `serialization_and_versioning.md`
- `authority_runtime_integration.md`
- `authority_store_adapter_shapes.md`
