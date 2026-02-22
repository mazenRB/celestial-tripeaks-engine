# CLI Reference

Last updated: 2026-02-21

Reference CLI entrypoint:

```bash
dart run bin/tripeaks_cli.dart [seed] [flags...]
```

## Interactive Commands

- `help`
- `show`
- `moves`
- `hint`
- `play`
- `auto [steps]`
- `score`
- `fingerprint`
- `draw [slot]`
- `undo`
- `take <index> [slot]`
- `expire [token]`
- `abort [skip|quit|timeout|disconnect]`
- `next`
- `new`
- `match show`
- `match commit <playerId> [roundScore]`
- `match bonus <playerId>`
- `match rank <playerId> <rank>`
- `match reset`
- `replay show`
- `replay save <file>`
- `replay load <file>`
- `replay step <count>`
- `quit`

Empty input repeats the last command.

## Command Aliases

- `?` -> `help`
- `q` -> `quit`
- `s` -> `show`
- `mv` -> `moves`
- `hn` -> `hint`
- `sc` -> `score`
- `d` -> `draw`
- `t` -> `take`
- `u` -> `undo`
- `n` -> `next`
- `a` -> `abort`
- `x` -> `expire`
- `rp` -> `replay`
- `mt` -> `match`
- `fp` -> `fingerprint`

## Startup Flags

### Session and Round

- `--rounds=3|6|10`
- `--invalid-penalty=<int>`
- `--wrap-ace-king=true|false`

### Undo and Hint

- `--undo-enabled=true|false`
- `--undo-max-steps=<int>`
- `--hints-enabled=true|false`

### Streak and Strike Timer

- `--streak-enabled=true|false`
- `--streak-reset-on-draw=true|false`
- `--streak-reset-on-invalid=true|false`
- `--streak-max-gap=<int>`
- `--strike-enabled=true|false`
- `--strike-timeout=<int>`

### Bonus Slots

- `--bonus-spawn-policy=joker|tier-fixed-rank|tier-random-rank`
- `--bonus-default-tier=low|high`
- `--bonus-joker-any=true|false`
- `--bonus-joker-consume=true|false`
- `--bonus-slot2-streak=<int>`
- `--bonus-slot3-streak=<int>`
- `--bonus-close-on-draw=true|false`
- `--bonus-close-on-invalid=true|false`

### Match Scoring

- `--first-finish-bonus=<int>`
- `--rank-adjustments=<rank:points,...>`

Example:

```bash
dart run bin/tripeaks_cli.dart 42 \
  --rounds=6 \
  --invalid-penalty=-3 \
  --first-finish-bonus=5 \
  --rank-adjustments=1:10,2:4,3:0
```

## Workflow Examples

### Replay

```text
replay show
replay save replay.json
replay load replay.json
replay step 25
```

### Match Scoring

```text
match commit p1 120
match bonus p1
match rank p1 1
match show
```
