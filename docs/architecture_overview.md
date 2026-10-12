# Architecture Overview

Last updated: 2026-10-12

The package separates deterministic game mechanics, optional match
orchestration, replay verification, and application services.

## Public Entry Points

- `tripeaks_engine.dart` owns round/session rules, presets, scoring, and
  deterministic timer actions.
- `tripeaks_replay.dart` records and reconstructs one player's session.
- `tripeaks_helpers.dart` compares completed independent runs.
- `tripeaks_multiplayer.dart` provides optional room and match reducers.
- `tripeaks_authority.dart` verifies a submitted session by replay.

The single-player engine remains usable without importing multiplayer APIs.
Each match participant has a private deterministic session. Async compares
two complete independent runs; Live coordinates multiple independent runs at
round barriers.

## Engine and Application Responsibilities

The engine owns serializable game and match data, deterministic reducers,
shared seed/rule handling, round and intermission progression, and replay
validation. It does not own UI, presentation strings, animation, wall-clock
reads, networking, identity, presence, invitations, storage, or notifications.

Hosts supply explicit timer actions and authenticate incoming events. Apps may
choose persistence, transport, and display behavior without reimplementing
TriPeaks scoring or match progression.

## Determinism

Every state transition is derived from its prior state, action, seed, and
configuration. No reducer reads wall-clock time or uses unseeded randomness.
Public room, match, event, and result payloads are versioned and serializable.
