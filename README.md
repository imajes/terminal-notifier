# terminal-notifier (tn)

Post macOS notifications from the terminal. This is a modern Swift rewrite of terminal-notifier with a CLI‑first UX, supporting both subcommands (preferred) and legacy flags for compatibility.

- Minimum macOS: 13 (Ventura) and newer
- Swift: 5.10+/6 via SwiftPM
- Architectures: arm64 and x86_64 (universal builds planned)

Status: 0.1.0‑dev. The CLI, validation, and IPC framing are implemented with tests. A minimal LSUIElement shim app for real notification posting/callbacks is planned; until then, Engine prints stub output to stdout when no shim is present.


## Getting Started

- Build (debug): `swift build`
- Build (release): `swift build -c release`
- Run help: `swift run tn --help`

If sandboxing is strict on your machine, prefer the local SPM helper which redirects caches into the workspace:

- `bin/spm build`
- `bin/spm test`


## Usage

Modern subcommands (preferred):

- Send: `swift run tn send --message "Hello" --title "Greeter"`
- Read from stdin: `echo "Hello from pipe" | swift run tn`
- List (TSV): `swift run tn list ALL` or `swift run tn list my-group`
- Remove: `swift run tn remove ALL` or `swift run tn remove my-group`
- Profiles: `swift run tn profiles list` / `profiles install default` / `profiles doctor [NAME]`
- Doctor: `swift run tn doctor`

Common send options:

- `--title STRING`, `--subtitle STRING`, `--message STRING`
- `--sound NAME` (e.g., `default`)
- `--group ID`
- `--open URL`, `--execute CMD`, `--activate BUNDLE_ID`
- `--content-image PATH|URL`
- `--sender PROFILE`
- `--interruption-level passive|active|timeSensitive` (default `active`)
- `--wait SECONDS` (wait for click action result)

Legacy flags (compat mode) at top level map to the same behavior:

- Example: `swift run tn -message "Hello" -title "Greeter"`
- Listing/removal: `swift run tn -list ALL`, `swift run tn -remove -group my-group`
- Shortcuts: `-help`, `-version` are supported
- Removed: `-ignoreDnD` (use `--interruption-level timeSensitive`)

Exit codes:

- `0` success; `1` runtime error; `2` usage error
- `70` notifications not authorized; `71` click action failed


## Profiles (sender identity)

You cannot spoof arbitrary third‑party app identities. Notifications should use a posting bundle. This project will ship tiny LSUIElement shim bundles (“profiles”) like `default`, `codex`, `buildbot` to provide stable names/icons and handle callbacks.

- Discover: `swift run tn profiles list`
- Install: `swift run tn profiles install default`
- Diagnose: `swift run tn profiles doctor [NAME]`

Environment override: set `TN_PROFILES_DIR` to choose a custom profiles base directory (useful for testing).


## IPC and Shim

When a shim is present, tn communicates via a small Unix‑domain socket protocol: `u32 length (BE) + JSON`.

- Client environment: set `TN_SHIM_SOCKET` to the socket path to force IPC usage.
- Requests: `SendRequest`, `ListRequest`, `RemoveRequest` (JSON‑codable structures)
- Responses: `Result { correlationID, status, message }`

Until the shim lands, without `TN_SHIM_SOCKET`, `tn send` prints a stub line like `posted\t<group>\t<title>\t<subtitle>\t<message>` to stdout instead of displaying a real notification. This keeps the CLI and validation testable while the shim is implemented.


## Development

Preferred workflow uses `just` (see Justfile):

- Format: `just fmt` or `just fmt-check`
- Lint: `just lint` or `just lint-fix`
- Build: `just build` (debug) or `just release`
- Test: `just test`
- Run: `just run -- --help` or `just run -- send --message "Hello"`
- Clean: `just clean`

Direct scripts remain available if you don’t use `just`:

- Format: `bin/format --check` (lint only) or `bin/format` (apply)
- Lint: `bin/lint` (strict) or `bin/lint fix`
- Build: `swift build` or `bin/spm build`
- Test: `swift test` or `bin/spm test`

Conventions:

- Async/await; throwing errors mapped to exit codes
- User data to stdout; diagnostics to stderr (`swift-log`)
- Respect `NO_COLOR`
- Follow Conventional Commits for PRs (e.g., `feat:`, `fix:`, `docs:`)


## Spec & Roadmap

Functional and technical requirements are tracked in `SPECIFICATION.md`. The staged build plan is in `AGENT_STEPS.md`.

Upcoming milestones:

- Implement the LSUIElement shim app and real posting via `UserNotifications`
- Wire click actions (`--open`, `--execute`, `--activate`) with optional `--wait`
- Homebrew distribution and universal release artifacts


## License

TBD.
