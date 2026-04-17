# Architecture Overview

Last updated: 2026-04-17

Celestial TriPeaks is a deterministic single-run game engine. It owns the
rules for one player session, replay and validation primitives, and a small
neutral helper surface for post-run processing.

## Public Entry Points

- `tripeaks_engine.dart`
  - round and session state
  - reducers, configs, presets, daily seeding, hints, deal policy
- `tripeaks_replay.dart`
  - replay recording, reconstruction, save/load envelopes
- `tripeaks_helpers.dart`
  - completed-run DTOs
  - deterministic comparison and helper scoring across finished runs

## Boundary

Engine-owned concerns:

- deterministic gameplay rules
- deterministic seeds and config-driven tuning
- replay reconstruction and fingerprint validation
- serializable public state, actions, and helper payloads

App or backend concerns:

- room handling and matchmaking
- presence, transport, and identity
- result submission and leaderboard storage
- tournament flow and multiplayer orchestration

## Core Invariants

- same seed + same config + same ordered actions => same state
- same replay log => same reconstructed state
- public payloads are versioned and serializable
- decode failures are typed instead of thrown for normal bad payloads

## Extension Guidance

- add new mechanics by extending core state, config, and reducer logic
- keep orchestration outside the engine boundary
- add non-core post-run utilities under `tripeaks_helpers.dart`
