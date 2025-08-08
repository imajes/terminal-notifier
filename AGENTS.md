# AGENTS

Define the staged work your code generator should do. Each agent has inputs, outputs, and pass criteria.

## Agent 0 — Bootstrap
**Do**
- Create SwiftPM package with targets: `tn` (executable), `TNCore` (library).
- Add `.gitignore`, `Makefile` with `build`, `release`, `test`.
**Pass**: `swift build` + `swift test` compile locally.

## Agent 1 — CLI & Compatibility Layer
**Do**
- Implement modern subcommands using `swift-argument-parser`: `send`, `list`, `remove`, `profiles`, `doctor`.
- Implement **compat parser** that maps legacy top‑level flags to `send/list/remove` logic.
- Stdin message fallback when `-message` omitted and stdin non‑TTY.
**Pass**: `tn --help` shows both UX styles; parser tests green.

## Agent 2 — Core Engine
**Do**
- `NotificationPayload` model + validation (title/subtitle/message, group, sound, interruptionLevel, actions, attachments).
- URL validation; attachment fetching to temp file; size/type checks.
- Group replacement semantics before posting.
**Pass**: unit tests for validation and payload building.

## Agent 3 — IPC protocol
**Do**
- Define framed JSON over UNIX domain socket: `SendRequest`, `ListRequest`, `RemoveRequest`, `Result` (with correlation IDs).
- Client (`tn`) auto‑launches chosen shim if no server, then retries for ~1s with backoff.
**Pass**: round‑trip tests succeed.

## Agent 4 — Notifier Shim (per‑profile)
**Do**
- LSUIElement app with `UNUserNotificationCenter.current()` delegate.
- First post requests authorization; handle denial.
- Implement actions (`open`, `activate`, `execute`) and callback to client for `--wait`.
- Set `UNNotificationContent.interruptionLevel` from payload, including `.timeSensitive` when entitlement present.
**Pass**: manual test posts a visible banner after grant; click actions work.

## Agent 5 — Profiles
**Do**
- Implement `-sender` profile selection and `tn profiles list/install/doctor`.
- `doctor` checks: authorization status, entitlement presence for timeSensitive, and Settings state; prints remediation.
**Pass**: switching profiles changes visible app name/icon.

## Agent 6 — Listing & Removal
**Do**
- `list` (TSV: GroupID \t Title \t Subtitle \t Message \t DeliveredAt).
- `remove GROUP|ALL` using `UNUserNotificationCenter` delivered set.
**Pass**: integration tests show correct behavior across multiple posts.

## Agent 7 — Packaging
**Do**
- Universal build for `tn` and profile shims.
- Codesign shims (Developer ID) with hardened runtime; notarize archive.
- Brew formula that installs CLI + shims and provides shell completions.
**Pass**: `brew test` can run `tn send -message ok` non‑blocking.

## Agent 8 — CI
**Do**
- GitHub Actions matrix: macOS 13–15; Swift 5.10/6.
- Run unit + integration tests headless.
**Pass**: green matrix.

## Agent 9 — Migration docs
**Do**
- `MIGRATION.md`: old→new flag table; `ignoreDnD` → `--interruption-level timeSensitive`; `-sender` explanation (profiles).
**Pass**: reviewed and consistent with SPEC.
