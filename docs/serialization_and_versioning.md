# Serialization and Versioning

Last updated: 2026-10-12

## Rules

- Public payloads include `schemaVersion`.
- Payload families include `type` when a decoder needs explicit discrimination.
- Decoders return `DecodeResult<T>` with typed failures.
- Unsupported schemas return `DecodeFailureCode.unsupportedSchemaVersion`.
- Changes to public payloads need an additive decode path or a schema bump and
  migration plan.

## Public Payload Families

- Core round, session, config, and action payloads.
- Replay and save envelopes.
- Completed-run helper results.
- Optional multiplayer room, match, event, and result payloads.

Multiplayer state is deterministic game data, not transport or backend
metadata. Presence, authenticated identities, reconnect state, and storage
schemas remain application responsibilities.
