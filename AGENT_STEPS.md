# AGENT_STEPS.md

# Purpose

Build a modern, CLI-first macOS notification tool (`tn`) per SPECIFICATION.md with:

- Modern subcommands (preferred) + legacy flag compatibility
- CLI primary; optional LSUIElement shim for identity/click callbacks and time-sensitive alerts
- No third-party repo code; follow Apple docs

# Conventions

- Language: Swift 5.10+/6, macOS 13+
- Style: async/await, throwing errors, swift-log
- Output: user data → stdout; diagnostics → stderr
- Exit codes: 0 OK, 1 runtime, 2 usage, 70 not authorized, 71 click failed
- Tests: Swift Testing; target ≥80% overall, ≥90% core

---

## Step 0 — Read & Sanity Check

**Goal:** Confirm scope and constraints.
**Inputs:** `SPECIFICATION.md`, `AGENTS.md`, project tree
**Actions:**

- Validate Package.swift targets exist: `tn`, `TNCore`
- Confirm `Sources/tn/main.swift` scaffold and `TNCore` models exist
  **Deliverables:** short comment in PR summarizing scope, any mismatches
  **Done when:** tree matches spec; mismatches listed

---

## Step 1 — CLI & Legacy Adapter

**Goal:** One command surface: modern subcommands + legacy flags mapped to same code paths.
**Inputs:** SPEC (CLI), scaffold in `Sources/tn/main.swift`
**Actions:**

- Implement subcommands: `send`, `list`, `remove`, `profiles`, `doctor`
- Implement legacy flags at top level: `-message`, `-list`, `-remove`, etc.
- Stdin fallback (non-TTY) when `-message` omitted
- Strict validation + exit codes
  **Deliverables:** updated `main.swift`, help text, parser tests
  **Done when:**
- `tn --help` shows both UXs
- `echo hi | tn` works
- Tests pass

---

## Step 2 — Core Models & Validation

**Goal:** Pure, testable core.
**Inputs:** SPEC (payload fields, rules)
**Actions:**

- Finalize `NotificationPayload`, `InterruptionLevel`
- Add validation helpers: URL schemes, attachment existence/size (~10MB), sound name pass-through
- Group semantics: replace delivered with same group before post
  **Deliverables:** `TNCore/Models.swift`, `TNCore/Validation.swift`, unit tests
  **Done when:** core tests ≥90% coverage, invalid inputs map to exit 2

---

## Step 3 — IPC Protocol (CLI ↔ shim)

**Goal:** Robust, minimal IPC.
**Inputs:** SPEC (requests/responses)
**Actions:**

- Define UNIX socket path (per profile) and frame: `u32 length + JSON`
- DTOs: `SendRequest`, `ListRequest`, `RemoveRequest`, `Result{correlationID,status,message}`
- Implement client in `TNCore/IPC.swift` with retry + backoff (~1s), timeouts
  **Deliverables:** IPC code + encode/decode tests (including partial reads)
  **Done when:** round-trip encode/decode tests pass

---

## Step 4 — Engine Wiring

**Goal:** Route CLI → Core → IPC.
**Inputs:** Steps 1–3
**Actions:**

- `Engine.post/list/remove` call IPC
- Auto-launch shim by profile: `open -gja <shim>` then retry connect
- `--wait [seconds]` uses correlation IDs
  **Deliverables:** `TNCore/Engine.swift`, integration test harness (shim stub mocked)
  **Done when:** CLI paths call IPC; wait/timeout logic covered by tests

---

## Step 5 — Notifier Shim (default profile)

**Goal:** Minimal LSUIElement app that actually posts notifications.
**Inputs:** Apple docs (UNUserNotificationCenter, attachments, interruption level)
**Actions:**

- LSUIElement Info.plist; App lifecycle + `UNUserNotificationCenter` delegate
- On first post: `requestAuthorization` (alerts + sound); denial → error to client (70)
- Post `UNMutableNotificationContent` (title, subtitle, body, sound, attachment, group via `threadIdentifier`)
- Click actions: open URL, activate app, execute shell (user context); return result to client
- Implement `list/remove` via delivered notifications; TSV fields match spec
- Map `timeSensitive` when entitlement present; otherwise fall back to `active`
  **Deliverables:** `NotifierShim.app` target, code, manual test notes
  **Done when:** visible banner after grant; click actions work; returns results

---

## Step 6 — Profiles & Doctor

**Goal:** Multiple sender identities as separate shim bundles.
**Inputs:** SPEC (profile behavior)
**Actions:**

- `tn profiles list|install NAME|doctor [NAME]`
- Registry of known profiles (local dir or URL); install copies signed .app into prefix
- `doctor`: show authorization, entitlement availability, timeSensitive allowance + remediation steps
  **Deliverables:** profiles code + docs
  **Done when:** switching profile changes app name/icon; doctor outputs actionable status

---

## Step 7 — Fallback (optional)

**Goal:** Basic banner without shim (no actions).
**Inputs:** N/A
**Actions:**

- If shim unavailable and user forces fallback: run `osascript display notification ...`
- Warn that actions/timeSensitive won’t work
  **Deliverables:** guarded code path + help text
  **Done when:** fallback prints warning and exits 0 on basic post

---

## Step 8 — Packaging & CI

**Goal:** Reproducible builds.
**Inputs:** Signing creds (local), CI environment
**Actions:**

- Universal builds (arm64/x86_64)
- Codesign shim(s) (Dev ID, hardened runtime); notarize release zip
- GitHub Actions matrix (macOS 13–15; Swift 5.10/6); SwiftFormat check; tests
- Brew formula that installs `tn` + shims and provides completions
  **Deliverables:** scripts, workflow, formula
  **Done when:** fresh machine: `brew install` → `tn send -message ok` works

---

## Step 9 — Docs & Migration

**Goal:** Accurate user docs.
**Inputs:** Implemented behavior
**Actions:**

- Update README (modern + legacy examples)
- `MIGRATION.md`: legacy→modern mapping; ignoreDnD→timeSensitive
- `tn(1)` manpage generated from help
  **Deliverables:** docs + manpage
  **Done when:** examples tested in CI
