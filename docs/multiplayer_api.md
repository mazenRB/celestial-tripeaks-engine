# Multiplayer API

Last updated: 2026-10-12

Import `tripeaks_multiplayer.dart` with the core engine when an app needs
deterministic rooms and match coordination. Import `tripeaks_authority.dart`
when a host or backend must replay and verify submitted results.

## Shared Game Model

Every participant owns an independent TriPeaks session. The engine creates the
same deterministic deal for each participant from the match seed and shared
rules. It returns complete match scores and per-round scores; it does not
provide presentation text, colors, animations, matchmaking, or transport.

## Async: Full-Match 1v1

Async matches require exactly two participants. Each player can complete the
entire multi-round session independently. A match completes after both sessions
finish, either participant withdraws, or the configured deadline expires. The
default deadline is seven days; set `asyncDeadlineSeconds` to `null` to disable
it. Hosts advance deadlines with explicit reducer events so the engine has no
wall-clock dependency.

## Live: Shared Round Progression

Live rooms can contain two or more participants. Each player acts on their own
session. A round is complete for that player after a win, loss, or the existing
round timer expires. The engine waits until every fixed room participant has
completed that round before opening the intermission.

Live uses the existing `RoundTimerConfig` schedule. Configure one positive
duration per ruleset round; the match starts each timer through the existing
`StartRoundTimerAction`. Preset-backed apps can pass a mode bundle's existing
timer configuration, for example `TriPeaksModeBundle.celestial.roundTimerConfig`.

The intermission defaults to 15 seconds. Each participant can vote to skip;
unanimity is the default threshold. Both duration and required vote fraction
can be configured. Once the threshold is met or the intermission expires, the
engine starts the next round for every participant together. A round result
does not eliminate a player from later rounds.

## Deterministic Time and Authority

The reducers never read `DateTime.now()`. Integrating hosts advance the Live
intermission and Async deadline with token-checked actions. Round gameplay
timers continue to use the existing timer actions and deadline tokens.

`verifyMatchSubmission` checks that the player belongs to the match, that the
replay uses the shared seed and rules, and that deterministic replay reaches a
completed session. The host or backend remains responsible for authenticating
who submitted an event and deciding when to dispatch clock events.

The package does not supply networking, authentication, storage, discovery,
presence, invites, notifications, or backend-specific document schemas.

## Serialization

Room, match, event, and result maps include `schemaVersion` and a `type`. Their
decoders return typed `DecodeResult` failures for malformed or unsupported
payloads. Room and match reducers are pure and ordered event sequences can be
replayed to reproduce the same state.
