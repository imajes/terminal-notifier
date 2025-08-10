# AGENTS.md — Repo Rules for Autonomous Agents

This document is the authoritative source of truth for **any agent**—human or artificial—interacting within this repository. It merges and supersedes guidance from other internal standards. If an instruction appears to conflict with another document, **AGENTS.md wins**.

## Context

- SwiftPM repo (Swift 5.10+/6, macOS 13+).
- **Package.swift**: manifest.
- **Sources/tn**: CLI entry (`main.swift`) + subcommands.
- **Sources/TNCore**: core engine/models.
- **Tests/TNCoreTests**: Swift Testing tests.
- **SPECIFICATION.md**: functional/technical requirements.
- **AGENT_STEPS.md**: current build sequence.

### Agent Environment Toggle

- `TN_AGENT_DISABLE_SWIFT_SANDBOX=1`: When set, `bin/spm` passes `--disable-sandbox` to `swift run` and `swift test`. This avoids double-sandboxing in agent harnesses so builds/tests run entirely within the workspace. Humans should not set this for normal local development.

### Useful commands

- `swift build` / `swift build -c release`
- `swift run tn --help`
- bin/format --check / bin/format
- bin/lint / bin/lint fix
- `swift test`
- Example: `swift run tn send --message "Hello"` or legacy `swift run tn -message "Hello"`

---

## Change Scope

- Only modify files relevant to assigned task.
- No unrelated renames/restructures.
- Keep changes cohesive and minimal per commit/PR.

## Coding Standards

- async/await; no main-thread blocking.
- Error handling: `throws` → map to exit codes.
- Public APIs documented; follow `swift-format` config.
- CLI glue in `Sources/tn`, core logic in `Sources/TNCore`.
- Add validation, proper exit codes, and tests for both the modern and legacy interfaces as described in the spec.
- Follow Swift style conventions (argument-parser idioms, async/await, throwing errors), document public APIs, and ensure all new code is covered by Swift Testing unit tests.
- After each phase of work, or similar stopping point, run lint/format to ensure that we keep aligned to swift style standards. Work to reduce lint errors wherever possible.

## Testing

- All new code covered by unit/integration tests.
- Maintain/improve coverage; no broken tests.

## Commits & PRs

- Use Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- You MUST generate a commit for each atomic change. Use a meaningful commit message to describe it.
- When a remote repo is enabled, PRs must pass CI, update docs/tests if behavior changes, and reference SPEC/step.

## External References

- Use official Apple docs for platform behavior.
- No code from unverified third-party repos.
- Cite authoritative sources in comments if needed.

## File Safety

- Don’t change `.gitignore`, `Package.swift`, workflows or lint/format configuration code unless required by step.
- No secrets/credentials in repo.
- Avoid large (>1 MB) files unless required.

## Handoff & Blockers

- Leave comments for non-obvious decisions.
- Document blockers or partial work in PR description.
- Respect step order in `AGENT_STEPS.md`.

## Definition of Done

- Aligned with SPEC.
- Cohesive, tested, documented changes.
- Passes CI/style/coverage gates.
