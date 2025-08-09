import ArgumentParser
import Darwin
import Foundation
import Logging
import TNCore

@main
struct TN: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "tn",
    abstract: "Post macOS notifications from the terminal.",
    discussion: "Use modern subcommands (e.g. 'tn send') or legacy top-level flags (e.g. '-message', '-title').",
    version: VersionInfo.string,
    subcommands: [Send.self, ListCmd.self, Remove.self, Profiles.self, Doctor.self],
    helpNames: [.long, .short]
  )

  /// Custom entry to rewrite legacy single-dash long flags (e.g. `-message`) into
  /// their modern `--message` equivalents before ArgumentParser runs. Also handles
  /// `-list ID` / `-remove ID` value shorthands and maps `-help`/`-version`.
  static func main() async {
    var args = CommandLine.arguments
    // Early error for removed flags.
    if args.contains("-ignoreDnD") {
      fputs("error: '-ignoreDnD' was removed; use --interruption-level timeSensitive\n", stderr)
      Darwin.exit(2)
    }

    args = rewriteLegacy(args)
    do {
      var command = try Self.parseAsRoot(Array(args.dropFirst()))
      if var asyncCommand = command as? any AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch let e as ExitCode {
      Self.exit(withError: e)
    } catch {
      // Delegate printing/exit code mapping to ArgumentParser.
      Self.exit(withError: error)
    }
  }

  /// Rewrites legacy single-dash long options to `--` form and shorthands.

  private static func rewriteLegacy(_ argv: [String]) -> [String] {
    guard argv.count > 1 else {
      // If no args and stdin is piped, default to `send`.
      if isatty(fileno(stdin)) == 0 { return [argv[0], "send"] }
      return argv
    }
    let subcommands = Set(["send", "list", "remove", "profiles", "doctor"])
    var tokens = Array(argv.dropFirst())

    // Map shortcuts for help/version.
    tokens = tokens.map { $0 == "-help" ? "--help" : ($0 == "-version" ? "--version" : $0) }

    // Normalize legacy single-dash long options to `--` form for send.
    var normalized: [String] = []
    var i = 0
    while i < tokens.count {
      let tok = tokens[i]
      if tok == "-list" || tok == "-remove" {
        // Handle later in dispatch.
        normalized.append(tok)
        i += 1
        continue
      }
      if tok.hasPrefix("-") && !tok.hasPrefix("--") {
        let name = String(tok.dropFirst())
        let legacyLongs: Set<String> = [
          "message", "title", "subtitle", "sound", "group", "open", "execute", "activate", "contentImage", "sender",
          "wait",
          // accept dashed form for interruption-level
          "interruption-level",
        ]
        if legacyLongs.contains(name) {
          normalized.append("--" + name)
          i += 1
          continue
        }
      }
      normalized.append(tok)
      i += 1
    }

    // Determine if user already chose a modern subcommand.
    let hasExplicitSubcommand = normalized.contains { !$0.hasPrefix("-") && subcommands.contains($0) }

    // Legacy list/remove at top level → subcommand.
    if let idx = normalized.firstIndex(of: "-list") {
      var group = "ALL"
      if idx + 1 < normalized.count, !normalized[idx + 1].hasPrefix("-") { group = normalized[idx + 1] }
      return [argv[0], "list", group]
    }
    if let idx = normalized.firstIndex(of: "-remove") {
      var group = "ALL"
      if idx + 1 < normalized.count, !normalized[idx + 1].hasPrefix("-") { group = normalized[idx + 1] }
      // also support '-remove -group X'
      if let gidx = normalized.firstIndex(of: "--group"), gidx + 1 < normalized.count,
        !normalized[gidx + 1].hasPrefix("-")
      {
        group = normalized[gidx + 1]
      }
      return [argv[0], "remove", group]
    }

    // If no explicit subcommand but legacy send-style flags are present or stdin is piped, default to `send`.
    if !hasExplicitSubcommand {
      let legacyMarkers: Set<String> = [
        "--message", "--title", "--subtitle", "--sound", "--group", "--open", "--execute", "--activate",
        "--contentImage", "--sender", "--interruption-level", "--wait",
      ]
      let hasLegacy = normalized.contains { legacyMarkers.contains($0) }
      let piped = isatty(fileno(stdin)) == 0
      if hasLegacy || piped {
        return [argv[0], "send"] + normalized
      }
    }

    // Otherwise, keep as-is.
    return [argv[0]] + normalized
  }
}

struct Send: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Post a notification.")

  @Option(help: "Notification title.")
  var title: String?

  @Option(help: "Notification subtitle.")
  var subtitle: String?

  @Option(help: "Notification body. If omitted and stdin is non-TTY, reads from stdin.")
  var message: String?

  @Option(help: "System sound name (use 'default' for system default).")
  var sound: String?

  @Option(help: "Notification group identifier.")
  var group: String?

  @Option(help: "URL to open on click.")
  var open: String?

  @Option(help: "Shell command to run on click.")
  var execute: String?

  @Option(help: "Bundle identifier to activate on click.")
  var activate: String?

  @Option(help: "Path or URL to image attachment.")
  var contentImage: String?

  @Option(help: "Sender profile name (selects shim bundle).")
  var sender: String?

  @Option(
    name: .customLong("interruption-level"),
    parsing: .next,
    help: "passive|active|timeSensitive (default: active)"
  )
  var interruption: String?

  @Option(help: "Wait N seconds for click action result (default: 30).")
  var wait: Int?

  mutating func run() async throws {
    let log = Logger(label: "tn")

    var body = message
    if body == nil, isatty(fileno(stdin)) == 0 {
      // Read stdin
      let data = FileHandle.standardInput.readDataToEndOfFile()
      body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let msg = body, !msg.isEmpty else {
      fputs("error: message is required (use --message or pipe stdin)\n", stderr)
      throw ExitCode(2)
    }

    // Validate interruption level if provided
    var level: InterruptionLevel = .active
    if let s = interruption {
      guard let parsed = InterruptionLevel(from: s) else {
        fputs("error: invalid --interruption-level: \(s)\n", stderr)
        throw ExitCode(2)
      }
      level = parsed
    }

    let payload = NotificationPayload(
      title: title ?? "Terminal",
      subtitle: subtitle,
      message: msg,
      groupID: group,
      sound: sound,
      openURL: open,
      execute: execute,
      activateBundleID: activate,
      contentImage: contentImage,
      senderProfile: sender,
      interruptionLevel: level,
      waitSeconds: wait
    )

    // Validate payload before dispatching to engine.
    do {
      try Validation.validate(payload)
    } catch let ve as TNValidationError {
      fputs("error: \(ve.description)\n", stderr)
      throw ExitCode(2)
    } catch {
      fputs("error: \(error)\n", stderr)
      throw ExitCode(1)
    }

    // Placeholder: delegate to TNCore Engine (to be implemented).
    try await Engine.post(payload: payload, logger: log)
  }
}

struct ListCmd: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "list", abstract: "List delivered notifications.")
  @Argument(help: "Group ID or ALL")
  var group: String = "ALL"
  mutating func run() async throws {
    try await Engine.list(group: group)
  }
}

struct Remove: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Remove delivered notifications.")
  @Argument(help: "Group ID or ALL")
  var group: String
  mutating func run() async throws {
    try await Engine.remove(group: group)
  }
}

struct Profiles: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Manage sender profiles (shim bundles).",
    subcommands: [ProfilesList.self, ProfilesInstall.self, ProfilesDoctor.self]
  )
}

struct ProfilesList: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "List known and installed profiles.")
  func run() throws {
    for info in try ProfilesManager.list() {
      print("\(info.name)\tinstalled=\(info.installed)\tpath=\(info.path)")
    }
  }
}

struct ProfilesInstall: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Install a profile.")
  @Argument var name: String
  func run() throws {
    let info = try ProfilesManager.install(name: name)
    print(info.path)
  }
}

struct ProfilesDoctor: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Doctor profiles state.")
  @Argument var name: String?
  func run() throws {
    let out = try ProfilesManager.doctor(name: name)
    print(out)
  }
}

struct Doctor: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Diagnose authorization/entitlement state.")
  func run() throws { print("doctor: checks authorization, entitlements, and focus config") }
}

enum VersionInfo {
  static let string = "0.1.0-dev"
}
