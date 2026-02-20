# CLI Guide (Beginner Friendly)

This guide helps you test the engine quickly.

## Start CLI

```bash
dart run bin/tripeaks_cli.dart --rounds=3 --bonus-spawn-policy=tier-fixed-rank
```

## Learn the board quickly

- `show` or `s`: print board/session
- `moves` or `mv`: print removable tableau indices
- `hint` or `hn`: deterministic suggested move

## Core gameplay commands

- `take <index> [slot]` or `t <index> [slot]`
- `draw` or `d`
- `undo` or `u`
- `abort [skip|quit|timeout|disconnect]` or `a ...`
- `next` or `n`

## Fast testing commands

- `play`: does one smart step
  - uses `hint` move if available
  - otherwise draws
  - if round already finished, starts next round
- `auto [steps]`: repeats `play` quickly (default `10`)
- empty line: repeats your last command

## Replay and verification

- `replay show`
- `replay save [file]`
  - if file omitted: auto name is generated
- `replay load <file>`
- `replay step <count>`
- `fp`: prints round/session/replay fingerprints
- `verify` (or `v`): prints `OK` when session fingerprint equals replay fingerprint

## Typical beginner workflow

1. `auto 20`
2. `fp`
3. `replay save`
4. `replay load <saved_file>`
5. `verify`

If `verify` prints `OK`, replay reconstruction matches current session state.

## Useful flags

- `--rounds=3|6|10`
- `--wrap-ace-king=true|false`
- `--invalid-penalty=<int>`
- `--bonus-spawn-policy=joker|tier-fixed-rank`
- `--bonus-default-tier=low|high`
- `--bonus-slot2-streak=<int>`
- `--bonus-slot3-streak=<int>`
- `--strike-enabled=true|false`
- `--strike-timeout=<int>`

For full list, run `help` inside CLI.

