# Serialization and Versioning

Last updated: 2026-02-21

## Scope

This document defines how state/action/config payloads are serialized,
versioned, validated, and migrated.

## Core Principles

- All public payloads are JSON-map compatible.
- Every serializable contract includes `schemaVersion` and `type`.
- Decoders are explicit and reject unknown/invalid version payloads.
- Fingerprints are used as deterministic integrity checks where applicable.

## Version Fields

### `schemaVersion`

- Represents payload shape version.
- Current canonical value is `1` for engine serialization contracts.
- Decode paths reject unsupported values.

Primary constant:

- `lib/src/serialization.dart` -> `_serializationSchemaV1 = 1`

### `engineVersion`

- Runtime/engine metadata used in save and authority persistence envelopes.
- Intended to track engine-level compatibility and operational visibility.

## Envelope Families

### 1) Core Engine Serialization

Examples:

- `round_action`, `session_action`
- `room_event`
- state/config payloads with specific `type` fields

Entry points:

- `roundActionToMap` / `roundActionFromMap`
- `sessionActionToMap` / `sessionActionFromMap`
- `tryDecodeRoomEvent(...)`
- `decodeStateMap` / `decodeActionMap`

### 2) Save Envelopes

- Save schema is separately versioned.
- Current save schema value is `1`.

Primary constant:

- `lib/src/save.dart` -> `_saveSchemaVersionV1 = 1`

Save payloads include:

- `schemaVersion`
- `type`
- `engineVersion`
- `payload`
- `fingerprint`

Fingerprint is recomputed on decode and must match.

### 3) Authority Persistence

- `persisted_authority_event`
- `persisted_authority_snapshot`

See `/docs/authority_runtime_schema.md` for exact durable payloads.

## Compatibility Policy

### During `0.x`

- Backward compatibility is best-effort, not guaranteed.
- Any contract-breaking change must update:
  - Changelog
  - Relevant docs in `/docs`
  - Decoder behavior and tests

### Forward-Compatible Decode Expectations

- Unknown schema versions should fail with typed decode errors.
- Unknown payload `type` should fail with typed decode errors.
- Callers should treat decode failures as non-recoverable for that payload,
  unless an explicit migration path exists.

## Migration Expectations

When introducing schema v2+:

- Keep v1 decoder path where migration support is required.
- Add explicit migration/adaptation logic in central decode hooks.
- Document v1->v2 migration behavior in this document and changelog.
- Add deterministic fixtures covering both legacy and new payloads.

## Integrator Checklist

- Persist complete payloads unchanged.
- Validate `schemaVersion` and `type` at every boundary.
- Log decode failures with version and type context.
- Use fingerprints for integrity checks in save/restore and authority replay
  boundaries.
- Treat room payloads as deterministic bootstrap contracts, not backend lobby
  documents. Do not attach invites, moderation, discovery, presence, or
  provider-specific fields to engine-owned room maps.
