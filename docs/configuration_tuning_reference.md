# Configuration Tuning Reference

Last updated: 2026-02-21

All tunable values below are modeled as config objects and injected into
state/reducer flows.

## Round and Session Mechanics

### `ScoreConfig`

Defaults:

- `pointsTableauToWaste = 5`
- `pointsDrawFromStock = 0`
- `penaltyInvalidAction = 0`
- `pointsPeakCleared = 0`
- `pointsPerRemainingStockCardOnWin = 0`
- `multiplierMode = streak`
- `streakStepSize = 999999`
- `multiplierStepIncrement = 0`
- `multiplierMax = 1`
- `timeBonusSecondsPerMove = 2`
- `timeBonusMaxSeconds = 10`
- `timeBonusMultiplier = 2`

Multiplier formula for successful tableau removals:

- `steps = (currentStreak <= 0) ? 0 : (currentStreak ~/ streakStepSize)`
- `multiplier = min(1 + steps * multiplierStepIncrement, multiplierMax)`
- `appliedMultiplier = max(1, multiplier)`

In PR1, multiplier applies only to tableau base points. Draw points and peak
bonus points are not multiplied.

Time bonus multiplier mode:

- Set `multiplierMode = timeBonus`.
- Timer adds `timeBonusSecondsPerMove` on each valid tableau removal, capped by
  `timeBonusMaxSeconds`.
- Timer resets on draw.
- While `remainingSeconds > 0` before a move, base tableau points are
  multiplied by `timeBonusMultiplier`.
- The first move after timer hits 0 is not multiplied (pre-move rule).
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

Risk notes:

- Disabling wrap-around reduces available removals and increases fail states.

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
