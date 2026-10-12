# Testing Strategy

Last updated: 2026-04-17

## Purpose

- preserve deterministic gameplay behavior
- catch serialization regressions early
- keep the engine usable through its public entrypoints

## Test Layers

- reducer-focused unit tests for round and session mechanics
- serialization round-trip tests
- replay parity tests
- helper-layer tests for completed-run comparison and scoring
- multiplayer room, Async match, Live barrier, and skip-vote reducer tests
- authority replay-verification and multiplayer serialization/replay tests

## Guardrails

- prefer deterministic fixtures over randomized tests
- assert exact score breakdowns when tuning matters
- use fingerprints as compact regression sentinels
- keep public entrypoint coverage focused on supported package imports
