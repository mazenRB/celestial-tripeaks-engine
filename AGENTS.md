# General
- For any change that affects architecture, public APIs, state shape, layering, or long-term extensibility, you MUST pause and present 2–3 architectural options with trade-offs and request explicit approval before implementation.
- If a file contains multiple responsibilities (e.g., domain models + rules + state transitions + scoring/session logic) or grows beyond ~300–500 lines, you MUST split it into separate modules by responsibility/layer (model, rules, engine/reducer, scoring, session) and keep the public API as re-exports from a single entry file.


# UNIVERSAL GAME ENGINE RULES (multiplayer-ready)
- Core gameplay must be a pure, deterministic state machine (no UI/IO, no randomness without seed, no time dependencies).
- Add features by composition (new layers/modules) rather than modifying core contracts.
- Separate: mechanics (state+rules) vs orchestration (levels/rounds/progression) vs presentation (UI) vs IO (save/network).
- Prefer additive API changes; keep public interfaces stable.
- State and actions must be serializable and versioned (schema/version fields, forward-compatible decoding).
- Every change must ship with unit tests and deterministic fixtures.
- All numeric game tuning values (score, penalties, bonuses, limits) must be configurable via injected policy/config objects and never hardcoded inside core mechanics.
- All public state and action types must be versioned and serializable, even if not yet used over network.

# Branch & PR Workflow (required)
- Never continue feature work on a branch that is intended for an open/unmerged PR unless the new work is explicitly part of that same PR scope.
- Before starting any new task, run and verify:
  - `git branch --show-current`
  - `git status --short`
  - `git rev-list --left-right --count main...HEAD`
- If current branch has pending PR commits and new scope is different, create a new branch before editing:
  - Use stacked PRs (new branch from current feature branch) if PR2 depends on PR1.
  - Use fresh branch from `main` if independent.
- If uncommitted changes already exist on the wrong branch:
  - Create/switch to the correct new branch first, then continue, or stash and re-apply deliberately.
- Keep `.DS_Store` and unrelated local artifacts out of commits.
- Commit discipline:
  - Use small logical commits (`feat`, `test`, `docs`) scoped to one workstream.
  - Do not mix unrelated fixes/features in one commit or one PR.
- Before proposing merge to `main`, always run and report:
  - `dart analyze`
  - `dart test`
- If no remote is configured, explicitly state that PRs cannot be opened yet and provide local-merge or remote-setup steps.
