# Contributing

Thanks for contributing to Celestial TriPeaks.

## Local Setup

1. Install Dart SDK `^3.3.0`.
2. Install dependencies:

```bash
dart pub get
```

3. Run tests:

```bash
dart test
```

## Quality Workflow

Recommended local workflow before opening a PR:

1. Run tests: `dart test`
2. Run analyzer (no warnings/errors expected): `dart analyze`
3. Ensure documentation updates are included for contract or config changes.

## Documentation Requirements

Update docs when any of the following change:

- public APIs exported from `lib/tripeaks_engine.dart`
- serialization envelope fields, schema behavior, or decode rules
- authority runtime sequencing/persistence behavior
- CLI commands/flags/default semantics
- config defaults or tuning behavior

Relevant docs index: `docs/INDEX.md`

## PR Checklist

- [ ] Tests added/updated for behavior changes.
- [ ] Existing tests pass locally (`dart test`).
- [ ] Public contract changes documented.
- [ ] `README.md` and `docs/INDEX.md` links remain accurate.
- [ ] Changelog entry added to `CHANGELOG.md` under `Unreleased`.

## Commit Guidance

- Keep commits focused and reviewable.
- Prefer additive changes with clear migration notes for compatibility impacts.
- Include deterministic reproduction details in bug fix PR descriptions.
