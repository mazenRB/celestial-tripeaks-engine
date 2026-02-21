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
- `streakStepSize = 999999`
- `multiplierStepIncrement = 0`
- `multiplierMax = 1`

Multiplier formula for successful tableau removals:

- `steps = (currentStreak <= 0) ? 0 : (currentStreak ~/ streakStepSize)`
- `multiplier = min(1 + steps * multiplierStepIncrement, multiplierMax)`
- `appliedMultiplier = max(1, multiplier)`

In PR1, multiplier applies only to tableau base points. Draw points and peak
bonus points are not multiplied.

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
- `appliedMultiplier`
- `totalDelta`

Invariant:

- `totalDelta == tableauBasePoints + multiplierExtraPoints + peakBonusPoints + drawPoints + invalidPenaltyPoints`

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
