# Configuration Tuning Reference

Last updated: 2026-02-21

All tunable values below are modeled as config objects and injected into
state/reducer flows.

## Preset Catalog

The engine exposes canonical named presets through `TriPeaksModePreset` and
resolved bundles through `TriPeaksModeBundle`.

- `classic` is the default standard single-round Solitaire TriPeaks preset.
- `celestial` is an engine-owned custom preset with centralized tuning values.
- Bundles also include `DealPolicyConfig`, so preset-backed match/server setup
  can reuse deterministic deal selection rules without rebuilding them.

Bundle serialization stores both `presetId` and the fully resolved nested
config values. Decode preserves those resolved values exactly and does not
re-resolve the current preset catalog, so previously serialized bundles remain
stable if tuning changes later.

## Round and Session Mechanics

### `ScoreConfig`

Defaults:

- `pointsTableauToWaste = 5`
- `pointsDrawFromStock = 0`
- `penaltyInvalidAction = 0`
- `pointsPeakCleared = 0`
- `pointsPerRemainingStockCardOnWin = 0`
- `multiplierMode = streak`
- `roundBasePointsGrowthBps = 0`
- `streakStepSize = 999999`
- `multiplierStepIncrement = 0`
- `multiplierMax = 1`
- `timeBonusSecondsPerMove = 2`
- `timeBonusMaxSeconds = 10`

Multiplier formula for successful tableau removals:

- `steps = (currentStreak <= 0) ? 0 : (currentStreak ~/ streakStepSize)`
- `multiplier = min(1 + steps * multiplierStepIncrement, multiplierMax)`
- `appliedMultiplier = max(1, multiplier)`

In PR1, multiplier applies only to tableau base points. Draw points and peak
bonus points are not multiplied.

Round-based base points progression:

- `roundBasePointsGrowthBps` compounds base tableau points by round.
- Growth factor per round: `growthFactorBps = 10000 + roundBasePointsGrowthBps`.
- Effective base uses per-round floor:  
  `effective = pointsTableauToWaste; for i in 2..roundNumber: effective = (effective * growthFactorBps) ~/ 10000`.

Time bonus multiplier mode:

- Set `multiplierMode = timeBonus`.
- Timer adds `timeBonusSecondsPerMove` on each valid tableau removal, capped by
  `timeBonusMaxSeconds`.
- Timer resets on draw.
- While `remainingSeconds > 0` before a move, base tableau points are
  multiplied by a progressive multiplier (x2, x3, x4, ...).
- The first move after timer hits 0 is not multiplied (pre-move rule).
- `stepCount` tracks already-multiplied moves in the active window.
- Multiplier formula when `remainingSeconds > 0` before a move:
  `multiplier = 2 + stepCount` then `stepCount++`.
- Host must dispatch `TimeBonusExpiredAction` and should schedule at most one
  expiry per `deadlineToken`.
- Expiry is rejected when `remainingSeconds == 0` (not armed) or when the
  deadline token is stale.

Risk notes:

- Large positive draw scoring can reduce strategic pressure.
- Large negative invalid penalty can make recoverability harsh.

### `ScoreDeltaBreakdown`

Accepted actions expose score components through `ScoreDeltaBreakdown`:

- `tableauBasePoints`
- `multiplierExtraPoints`
- `peakBonusPoints`
- `drawPoints`
- `invalidPenaltyPoints`
- `endRoundRemainingStockBonusPoints`
- `appliedMultiplier`
- `totalDelta`

Invariant:

- `totalDelta == tableauBasePoints + multiplierExtraPoints + peakBonusPoints + drawPoints + invalidPenaltyPoints + endRoundRemainingStockBonusPoints`

Example:

```dart
final breakdown = state.scoreState.lastBreakdown;
print('delta=${breakdown.totalDelta}');
print('multiplier=${state.scoreState.currentMultiplier}');
```

### `RoundRulesConfig`

Default:

- `aceKingWrapAround = true`
- `startStockSize = 21`
- `stockDecreaseEveryRounds = 2`
- `minStockSize = 12`

Risk notes:

- Disabling wrap-around reduces available removals and increases fail states.
- Stock size progression uses the layout's tableau slot count and one waste
  card when validating availability.
- Stock size is computed per round:
  `max(minStockSize, startStockSize - (roundNumber ~/ stockDecreaseEveryRounds))`

### `UndoConfig`

Defaults:

- `enabled = true`
- `maxSteps = 10`

Risk notes:

- High `maxSteps` increases memory footprint for history snapshots.

### `HintConfig`

Defaults:

- `enabled = true`
- `selectionStrategy = firstPlayableByIndex`

Risk notes:

- Deterministic hints are stable, but strategy changes affect UX predictability.

### `StreakConfig`

Defaults:

- `enabled = true`
- `resetOnDraw = true`
- `resetOnInvalidAction = true`
- `maxGapTicks = null` (disabled)

Risk notes:

- Tight gap windows can over-reset streaks in slower transports.

### `StrikeTimerConfig`

Defaults:

- `enabled = true`
- `timeoutSeconds = 10`

Risk notes:

- Very short timeout may over-penalize players under latency.

### `BonusSlotsConfig`

Defaults:

- `maxSlots = 3`
- `spawnPolicy = tierFixedRank`
- `defaultAnchorTierWhenUnknown = low`
- `jokerAcceptsAnyRank = true`
- `jokerConsumedOnFirstUse = true`
- `spawnOnOpenSlot2AtStreak = 3`
- `spawnOnOpenSlot3AtStreak = 6`
- `closeOnDraw = true`
- `closeOnInvalidAction = true`

`tierRandomRank` policy:

- Uses deterministic rank selection inside tier domains.
- Low tier domain: `2..10`
- High tier domain: `A/J/Q/K`
- Determinism inputs include round seed, spawn nonce, canonical 1-based slot
  index, and explicit tier discriminator constants (`low=1`, `high=2`).
- Legacy session decode derives missing round seed from session seed + round
  index using the same deterministic round-seed formula.

`stockTopCard` policy:

- Applies only when newly opening slots `2` and `3`.
- Moves `stock.first` into the newly opened slot and removes it from stock.
- The spawned card is treated as a normal card, not a joker or anchor.
- Stock consumption has no draw side effects.
- If stock is empty, the slot does not open.
- `openSlotsCount` reflects actually opened slots, not just streak thresholds.

Risk notes:

- Lower slot unlock thresholds increase volatility and combo potential.
- Non-consuming joker behavior increases action forgiveness.

### `DealPolicyConfig`

Defaults:

- `mode = random`
- `attemptSeedStrategy = baseSeedPlusAttempt`
- `maxAttempts = 200`
- `solverNodeLimit = 300000`

Risk notes:

- Higher attempt/solver bounds improve solvability checks but increase CPU.

## Session and Match

### Session score surfaces

- `RoundResult.finalScore` is captured on new round completions and may be
  `null` only for legacy decoded payloads.
- `cumulativeFinishedRoundsScoreTotal` sums non-null finished round scores.
- `cumulativeIncludingCurrentRoundScoreTotal` adds current round score only when
  the current round is still in progress to avoid double-counting.
- Aborted rounds are included when a `finalScore` was captured at abort time.

### `TriPeaksRuleset`

Common presets:

- `oneRound`
- `threeRounds`
- `sixRounds`
- `tenRounds`

Risk notes:

- Longer sessions increase variance and time-to-completion.

### `MatchScoreConfig`

Defaults:

- `firstFinishBonus = 0`
- `rankingAdjustments = {}`

Risk notes:

- Large ranking deltas can dominate mechanics-derived scoring.

## Authority Runtime

### `AuthorityRuntimeConfig`

Defaults:

- `snapshotEveryAccepted = 100`
- `processedClientEventIdsCapacityPerPlayer = 1000`

Risk notes:

- Larger snapshot interval increases restore replay duration.
- Smaller duplicate-ID capacity increases duplicate false negatives.

## Tuning Guidelines

- Start with defaults and adjust one parameter family at a time.
- Validate deterministic replay equivalence after config changes.
- Use integration tests for authority restore/apply behavior under your
  chosen values.
