import ArgumentParser
import Logging
import TNCore

@main
struct TN: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tn",
    abstract: "Post macOS notifications from the terminal.",
    version: VersionInfo.string,
    subcommands: [Send.self, ListCmd.self, Remove.self, Profiles.self, Doctor.self],
    helpNames: [.long, .short]
  )

  // Legacy compatibility: parse top-level flags and route to subcommands.
  @Option(name: .customLong("message"), help: "Notification body.")
  var legacyMessage: String?

  @Option(name: .customLong("title"), help: "Notification title.")
  var legacyTitle: String?

  @Option(name: .customLong("subtitle"), help: "Notification subtitle.")
  var legacySubtitle: String?

  @Option(name: .customLong("sound"), help: "System sound name (use 'default' for system default).")
  var legacySound: String?

  @Option(name: .customLong("group"), help: "Notification group identifier.")
  var legacyGroup: String?

  @Option(name: .customLong("open"), help: "URL to open on click.")
  var legacyOpen: String?

  @Option(name: .customLong("execute"), help: "Shell command to run on click.")
  var legacyExecute: String?

  @Option(name: .customLong("activate"), help: "Bundle identifier to activate on click.")
  var legacyActivate: String?

  @Option(name: .customLong("contentImage"), help: "Path or URL to image attachment.")
  var legacyContentImage: String?

  @Option(name: .customLong("sender"), help: "Sender profile name (selects shim bundle).")
  var legacySender: String?

  @Option(name: .customLong("interruption-level"), parsing: .next, help: "passive|active|timeSensitive (default: active)")
  var legacyInterruption: String?

  @Flag(name: .customLong("list"), help: "List notifications for a group or ALL (use with --group or ALL).")
  var legacyList: Bool = false

  @Flag(name: .customLong("remove"), help: "Remove notifications for a group or ALL (use with --group or ALL).")
  var legacyRemove: Bool = false

  @Option(name: .customLong("wait"), help: "Wait N seconds for click action result (default: 30).")
  var legacyWait: Int?

  mutating func run() async throws {
    // If a subcommand is explicitly provided, ArgumentParser won't call this.
    // This is reached only when user used legacy flags without subcommand.
    if legacyList {
      let group = legacyGroup ?? "ALL"
      var cmd = ListCmd()
      cmd.group = group
      try await cmd.run()
      return
    }
    if legacyRemove {
      let group = legacyGroup ?? "ALL"
      var cmd = Remove()
      cmd.group = group
      try await cmd.run()
      return
    }

    // Legacy send fallback (including stdin handling).
    var cmd = Send()
    cmd.title = legacyTitle
    cmd.subtitle = legacySubtitle
    cmd.message = legacyMessage // Send handles stdin fallback if nil
    cmd.sound = legacySound
    cmd.group = legacyGroup
    cmd.open = legacyOpen
    cmd.execute = legacyExecute
    cmd.activate = legacyActivate
    cmd.contentImage = legacyContentImage
    cmd.sender = legacySender
    cmd.interruption = legacyInterruption
    cmd.wait = legacyWait
    try await cmd.run()
  }
}

struct Send: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Post a notification.")

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

  @Option(name: .customLong("interruption-level"), parsing: .next, help: "passive|active|timeSensitive (default: active)")
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
      throw ExitCode(2)
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
      interruptionLevel: InterruptionLevel(from: interruption) ?? .active,
      waitSeconds: wait
    )

    // Placeholder: delegate to TNCore Engine (to be implemented).
    try await Engine.post(payload: payload, logger: log)
  }
}

struct ListCmd: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List delivered notifications.")
  @Argument(help: "Group ID or ALL")
  var group: String = "ALL"
  mutating func run() async throws {
    try await Engine.list(group: group)
  }
}

struct Remove: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Remove delivered notifications.")
  @Argument(help: "Group ID or ALL")
  var group: String
  mutating func run() async throws {
    try await Engine.remove(group: group)
  }
}

struct Profiles: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Manage sender profiles (shim bundles).")
  func run() throws { print("Use: tn profiles [list|install NAME|doctor [NAME]]") }
}

struct Doctor: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Diagnose authorization/entitlement state.")
  func run() throws { print("doctor: checks authorization, entitlements, and focus config") }
}

enum VersionInfo {
  static let string = "0.1.0-dev"
}
