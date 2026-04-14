# Room Foundation

Last updated: 2026-04-14

## Purpose

The engine room layer is a deterministic bootstrap kernel, not a full lobby
domain model.

It owns only:

- deterministic membership state
- deterministic host selection and host transfer
- deterministic start validation
- canonical room-to-match bootstrap
- sequential rematch gating through explicit completion

## What The Engine Does Not Own

The room layer must not absorb backend or product concerns. Keep these out of
engine-owned room payloads and reducers:

- invites or deep links
- moderation, bans, reporting
- discovery, search, or listing metadata
- presence heartbeats or online-offline state
- reconnection transport state
- notification logic
- platform identity concerns
- Firebase-specific fields or document schemas

## Core Types

- `RoomConfig`
- `RoomState`
- `RoomMemberState`
- `RoomEvent`
- `RoomReduceResult`
- `MatchBootstrap`

## Lifecycle

### 1) Open Room

- Members may join or explicitly leave.
- Host is always the earliest currently joined member by `joinOrder`.
- If the host leaves, host transfers to the next eligible joined member.
- If no joined members remain, the room becomes `closed`.

### 2) Match Bootstrap

- Only the deterministic host may start the room.
- Joined member count must satisfy `minMembers <= count <= maxMembers`.
- Caller supplies `matchId` and `matchSeed`.
- Accepted start returns canonical `MatchBootstrap` containing both
  `MatchConfig` and the initial live `MatchState`.

### 3) Match In Progress

- Room membership is frozen while a live match is active.
- The room tracks the active `matchId` so overlapping starts are rejected.

### 4) Completion / Rematch

- `CompleteRoomMatchEvent(matchId: ...)` reopens the room after the active
  match ends.
- The same room may bootstrap a later rematch, but never more than one live
  match at a time.

## Integration Guidance

- Use room reducers when you need deterministic room ownership and bootstrap.
- Hand the resulting `MatchBootstrap.matchState` to authority/runtime flows.
- Keep social, backend, and transport layers outside the engine and compose
  them around these room contracts instead of embedding them into the room
  payloads.
