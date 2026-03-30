# Engine API Guide

Last updated: 2026-03-27

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
- `reduceTriPeaksSession(...)`
- `tryReduceTriPeaksSession(...)`

### Preset Packaging

- `TriPeaksModePreset`
- `TriPeaksModeBundle`

### Query/Hint

- `getHint(...)`
- `HintResult`

### Replay

- `TriPeaksReplay` (`ReplaySession` alias)
- `recordAction(...)`
- `replayAccepted(...)`

### Match/Multiplayer

- `MatchConfig`, `MatchState`, `MatchEvent`
- `tryReduceMatch(...)`
- `replayMatchEvents(...)`
- `MatchScoreState` and match-scoring events

## Terminology

- `round`: one playable TriPeaks board.
- `session`: a sequence of rounds for one player under one ruleset.
- `match`: multiplayer orchestration around one or more player sessions.
- `waste`: the primary playable pile used by normal draw and tableau-removal
  flow.
- `bonus slots`: optional additional playable piles. Internally, slot `1`
  mirrors the waste pile so slot-based mechanics can use one consistent model.
- `ruleset`: high-level round-count shape such as `oneRound` or `tenRounds`.
- `...Config`: detailed tuning objects for scoring, round rules, timers,
  streaks, undo, deal policy, and bonus-slot behavior.
- `TriPeaksModeBundle`: an engine-owned preset bundle that resolves to a full
  set of configs without replacing explicit config APIs.

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

Normal round flow should be described in terms of the `waste` pile. Bonus-slot
terminology matters when you explicitly target or inspect additional playable
piles.

Time bonus timer:

- `TriPeaksState.timeBonusTimerState` holds remaining seconds and deadline
  token.
- Host dispatches `TimeBonusExpiredAction(deadlineToken: ...)` to expire the
  timer.
- Host should schedule at most one expiry per token; resets/increments
  invalidate old tokens deterministically.
- `stepCount` tracks already-multiplied moves in the current active window.

Score breakdown:

- `tableauBasePoints`
- `multiplierExtraPoints`
- `peakBonusPoints`
- `drawPoints`
- `invalidPenaltyPoints`
- `endRoundRemainingStockBonusPoints`
- `appliedMultiplier`
- `totalDelta`

### 2) Session Loop

```dart
var session = TriPeaksSessionState.newSession(
  ruleset: TriPeaksRuleset.threeRounds,
  seed: 42,
);

final result = tryReduceTriPeaksSession(
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

`TriPeaksSessionStatus` is a compact derived helper for common UI states. It
does not replace round/session facts already present on the state.

### Preset-backed Session Setup

```dart
final bundle = TriPeaksModeBundle.forPreset(TriPeaksModePreset.classic);

final session = TriPeaksSessionState.newSession(
  ruleset: bundle.ruleset,
  scoreConfig: bundle.scoreConfig,
  roundRulesConfig: bundle.roundRulesConfig,
  undoConfig: bundle.undoConfig,
  streakConfig: bundle.streakConfig,
  strikeTimerConfig: bundle.strikeTimerConfig,
  bonusSlotsConfig: bundle.bonusSlotsConfig,
);
```

Serialized `TriPeaksModeBundle` payloads preserve their nested resolved config
values as written. Decode treats `presetId` as metadata and does not re-resolve
current catalog defaults.

`TriPeaksModeBundle` also carries `dealPolicyConfig` for server/match/deal
generation reuse.

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

### 4) Daily Presets

```dart
final session = newDailySessionForPreset(
  const DateOnly(2026, 2, 20),
  namespaceId: 'prod',
  preset: TriPeaksModePreset.celestial,
);
```

Preset-backed daily helpers derive `modeId` from the engine-owned preset id and
reuse the resolved bundle configs.

### 5) Authority Host Runtime

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

For scoring surfaces:

- `ScoreState.currentMultiplier` is the multiplier used on the most recent
  accepted action.
- `ScoreState.lastBreakdown` is the component-level score explanation stored on
  state.
- `TriPeaksReduceResult.scoreBreakdown` mirrors the resulting state's
  `lastBreakdown` for the accepted action result.

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
- `BonusSlotsState.openSlotsCount` means slots actually open now, not merely
  slots implied by streak thresholds in the abstract.
- `BonusSlotSpawnPolicy.tierRandomRank` selects low/high anchor ranks
  deterministically (seed + spawn nonce + 1-based slot index), replay-safe.
  Legacy session decode derives missing round seed from session seed + round
  index using the same round-seed formula as round creation.
- `BonusSlotSpawnPolicy.stockTopCard` opens newly unlocked slots `2` and `3`
  by moving `stock.first` into the slot without applying draw-side effects.
