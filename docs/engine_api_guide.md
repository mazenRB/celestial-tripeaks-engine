# Engine API Guide

Last updated: 2026-02-21

This guide focuses on practical integration using the public export surface in
`lib/tripeaks_engine.dart`.

## Core Types You Will Use

### Round Mechanics

- `TriPeaksState`
- `TriPeaksAction`
- `reduceTriPeaks(...)`
- `tryReduceTriPeaks(...)`

### Session Progression

- `TriPeaksSessionState`
- `TriPeaksSessionAction`
- `reduceSession(...)`
- `tryReduceSession(...)`

### Query/Hint

- `getHint(...)`
- `HintResult`

### Replay

- `TriPeaksReplay` (`ReplaySession` alias)
- `recordAction(...)`
- `replayAccepted(...)`

### Match/Multiplayer

- `MatchConfig`, `MatchState`, `MatchEvent`
- `reduceMatch(...)`
- `replayMatchEvents(...)`
- `MatchScoreState` and match-scoring events

### Authority Runtime

- `AuthorityRuntime`
- `AuthorityRuntimeState`
- `AuthorityRequestContext`
- `AuthorityApplyResult`
- `AuthorityRestoreResult`
- `AuthorityStorePort`

## Integration Recipes

### 1) Local Deterministic Round

```dart
final state = TriPeaksState.newGame(seed: 42);
final next = reduceTriPeaks(state, const DrawFromStockAction());
```

Use `tryReduceTriPeaks` when you need typed error handling without throws.

### 2) Session Loop

```dart
var session = TriPeaksSessionState.newSession(
  ruleset: TriPeaksRuleset.threeRounds,
  seed: 42,
);

final result = tryReduceSession(
  session,
  const PlayRoundAction(DrawFromStockAction()),
);
session = result.state;
```

Session score helpers:

- `cumulativeFinishedRoundsScoreTotal`: sum of known `RoundResult.finalScore`
  entries.
- `cumulativeIncludingCurrentRoundScoreTotal`: includes current round score only
  while the current round is in progress (prevents double-counting finished
  rounds already in `roundResults`).

`RoundResult.finalScore` may be `null` for legacy decoded payloads; unknown
scores are skipped deterministically in cumulative totals.

### 3) Replay Logging

```dart
var replay = TriPeaksReplay.newSession(
  seed: session.seed ?? TriPeaksSessionState.defaultSeed,
  ruleset: session.ruleset,
);

final recorded = recordAction(
  replay,
  session,
  const PlayRoundAction(DrawFromStockAction()),
  tick: 1,
);

replay = recorded.replay;
session = recorded.reduceResult.state;
```

### 4) Authority Host Runtime

- Construct `AuthorityRuntime` with `AuthorityStorePort` implementation and
  baseline `MatchState` (sequence must start at `0`).
- Call `restore(matchId)` at startup.
- For each client event, call `apply(...)` with trusted
  `AuthorityRequestContext`.
- Persisted event append is runtime-managed through the store port.

See `/docs/authority_runtime_integration.md`.

## Error and Result Contracts

Use non-throwing APIs in host/integration boundaries:

- `TriPeaksReduceResult`
- `TriPeaksSessionReduceResult`
- `MatchReduceResult`
- `MatchScoreReduceResult`
- `AuthorityApplyResult`
- `AuthorityRestoreResult`

They carry typed failure payloads suitable for telemetry and protocol mapping.

## Serialization Entrypoints

Primary map/json contracts:

- `...toMap()` on state/action/config payloads.
- `tryFromMap(...)` decode paths that return typed decode failures.
- Save helpers in `lib/src/save.dart` for round/session/replay envelopes.

Detailed policy: `/docs/serialization_and_versioning.md`.

## Contract Guidance for Integrators

- Treat `schemaVersion` + `type` as mandatory decode gates.
- Persist payloads exactly as emitted by `toMap()`.
- Do not mutate envelope fields before persistence or transport.
- Keep engine version and schema version in logs and diagnostics.

Bonus-slot helper:

- `TriPeaksState.actionableBonusSlotIndices` returns sorted indices currently
  accepted by `UseBonusSlotAction(index)`.
- `BonusSlotSpawnPolicy.tierRandomRank` selects low/high anchor ranks
  deterministically (seed + spawn nonce + 1-based slot index), replay-safe.
  Legacy session decode derives missing round seed from session seed + round
  index using the same round-seed formula as round creation.
