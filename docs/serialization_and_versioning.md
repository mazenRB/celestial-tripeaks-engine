# Serialization and Versioning

Last updated: 2026-04-17

## Rules

- every public payload includes `schemaVersion`
- payload families include `type` when a decoder needs explicit discrimination
- decoders return `DecodeResult<T>` with typed failures
- unsupported schemas return
  `DecodeFailureCode.unsupportedSchemaVersion`

## Public Payload Families

- core round, session, config, and action payloads
- replay and save envelopes
- neutral helper payloads under `tripeaks_helpers.dart`

## Boundary

Serialization in this package is for deterministic gameplay and post-run helper
contracts only. Room state, transport payloads, presence metadata, and backend
documents are intentionally outside the engine boundary.
