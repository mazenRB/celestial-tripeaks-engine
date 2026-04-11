# Release Process

Last updated: 2026-04-11

This project currently ships as a private package through tagged GitHub
releases.

## Release Model

- Releases are triggered by pushing a git tag like `v1.0.0-beta.3`
- The tag must exactly match `pubspec.yaml` version without the `v`
- `CHANGELOG.md` must contain a matching `## [version]` entry
- Prerelease tags such as `-beta` or `-rc` are published as GitHub
  prereleases

## Required Steps Before Tagging

1. Update `pubspec.yaml` version.
2. Move the release notes from `Unreleased` into a versioned
   `CHANGELOG.md` section.
3. Ensure `dart format --output=none --set-exit-if-changed .`,
   `dart analyze`, and `dart test` pass locally.
4. Create and push the version tag.

Example:

```bash
git tag v1.0.0-beta.3
git push origin v1.0.0-beta.3
```

## What the Release Workflow Validates

- tag format follows semver with optional prerelease suffix
- tag version matches `pubspec.yaml`
- matching changelog entry exists
- formatting, analysis, and tests all pass
- `dart pub publish --dry-run` passes against a temporary package tree

## Why Publish Dry-Run Uses a Temporary Tree

The repository keeps `publish_to: none` and uses `docs/` for contributor
documentation. The release workflow builds a temporary validation tree that:

- renames `docs/` to `doc/`
- preserves the rest of the package contents

This keeps the repo private while still validating a future pub-quality
package layout.
