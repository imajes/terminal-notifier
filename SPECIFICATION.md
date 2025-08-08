# SPECIFICATION

## Objective
Rebuild **terminal-notifier** as a **CLI-first** Swift tool using **UserNotifications.framework** on macOS. Keep legacy flags for compatibility while introducing a **modern subcommand UX** (`tn send`, `tn list`, `tn remove`, …). No GUI is shipped to users beyond a **minimal on‑demand shim** app if required for reliable identity/click handling.

- **Minimum macOS:** 13 (Ventura) and newer.
- **Swift:** 5.10+/6.
- **Architectures:** arm64 + x86_64 (universal).
- **Identity:** Notifications display the **posting bundle’s** name/icon; a pure CLI has no presentable bundle. Use an **on‑demand LSUIElement shim** (hidden agent app) to post notifications and receive click callbacks when advanced features are used. Otherwise provide a simple `osascript` fallback for basic banners (no actions).

References: Apple documentation for `UNUserNotificationCenter` and authorization, `UNNotificationAttachment`, `UNNotificationInterruptionLevel.timeSensitive`, and `LSUIElement` agent apps.

## CLI UX

### Modern subcommands (preferred)
- `tn send [OPTIONS]` – post a notification.
- `tn list [GROUP|ALL]` – print delivered notifications for this sender profile (TSV).
- `tn remove [GROUP|ALL]` – remove delivered notifications.
- `tn profiles [list|install NAME|doctor [NAME]]` – manage sender profiles (shim bundles).
- `tn doctor` – diagnose authorization/entitlements and environment.

### Legacy flags (compat mode)
All legacy flags are accepted at the **top level** (no subcommand) for drop‑in replacement:

- `-message VALUE` (or stdin when omitted)
- `-title VALUE`, `-subtitle VALUE`
- `-sound NAME` (`default` allowed)
- `-group ID`
- `-list [ID|ALL]`, `-remove [ID|ALL]`
- `-open URL`, `-execute CMD`, `-activate BUNDLE_ID`
- `-contentImage PATH|URL`
- `-sender PROFILE` (see below)
- `--interruption-level active|passive|timeSensitive` (replaces `-ignoreDnD` which is **removed**)
- `--wait [SECONDS]`
- `-version`, `-help`

### `-sender` (sender profiles)
You cannot arbitrarily spoof third‑party apps. System identity is derived from the **posting bundle**. Implement `-sender` as a **profile selector** choosing a tiny LSUIElement shim with its own bundle ID + icon (e.g., `default`, `codex`, `buildbot`). If a requested profile isn’t installed, fail with a helpful message and show `tn profiles install <name>`.

### Interruption level / Focus
Map `--interruption-level` to `UNNotificationInterruptionLevel`:
- `passive`, `active` (default), `timeSensitive`.
`timeSensitive` requires a capability/entitlement on the **shim bundle** and user opt‑in. `tn doctor` surfaces status and remediation.

## Behavior

- **Authorization:** First post from a shim triggers `requestAuthorization`. Denied → exit 70 with next steps.
- **Groups:** Replace older delivered notifications with matching `groupID` before posting.
- **Attachments:** Support images via `UNNotificationAttachment`; download remote URLs to a temp file.
- **Actions on click:**
  - `-open`: `NSWorkspace.shared.open(URL)`
  - `-activate`: activate bundle id
  - `-execute`: run `/bin/sh -c` in user context; capture output to OSLog
  - `--wait`: CLI waits up to N seconds for callback; exit 0/71 accordingly
- **List/Remove:** Mirror `UNUserNotificationCenter` delivered set for this sender profile; TSV format for `list`.

## Exit Codes
- `0` success
- `1` runtime error (IPC, IO)
- `2` usage error
- `70` notifications not authorized for this bundle
- `71` click action failed

## Logging & IO
- Human‑readable results to **stdout** (e.g., `list`).
- Diagnostics to **stderr** using `swift-log`.
- Respect `NO_COLOR`.

## Distribution
- Homebrew formula installs `tn` and any chosen shim bundles.
- Universal build, codesign shims (Developer ID), notarize release zip.
- CLI stays CLI‑first; shims launch on‑demand and quit when idle.

