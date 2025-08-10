import AppKit
import Foundation
import Logging
import TNCore
import UserNotifications

@main
struct NotifierShimMain {
  static func main() async throws {
    let log = Logger(label: "tn.shim")
    let sock = ProcessInfo.processInfo.environment["TN_SHIM_SOCKET"] ?? "/tmp/tn-shim.sock"
    let fd = try openServerSocket(at: sock)
    log.info("shim listening at \(sock)")

    // Simple accept loop: handle one request per connection, reply, close.
    while true { try await acceptAndServe(from: fd) }
  }

  private static func openServerSocket(at path: String) throws -> Int32 {
    unlink(path)
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { fatalError("socket() failed") }
    var addr = sockaddr_un()
    let cstr = path.utf8CString
    #if os(macOS)
      addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    #endif
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in _ = raw.initializeMemory(as: CChar.self, from: cstr) }
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
    let bindRes = withUnsafePointer(to: &addr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
        Darwin.bind(fd, sp, addrLen)
      }
    }
    guard bindRes == 0, Darwin.listen(fd, 16) == 0 else { fatalError("bind/listen failed") }
    return fd
  }

  private static func acceptAndServe(from fd: Int32) async throws {
    var addr2 = sockaddr()
    var len = socklen_t(MemoryLayout<sockaddr>.size)
    let cfd = withUnsafeMutablePointer(to: &addr2) { ap in
      ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
        Darwin.accept(fd, sp, &len)
      }
    }
    if cfd < 0 { return }
    defer { Darwin.close(cfd) }

    // Read header
    var header = [UInt8](repeating: 0, count: 4)
    let r1 = header.withUnsafeMutableBytes { Darwin.read(cfd, $0.baseAddress, 4) }
    guard r1 == 4 else { return }
    let length = header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    var body = Data(count: Int(length))
    let r2 = body.withUnsafeMutableBytes { Darwin.read(cfd, $0.baseAddress, Int(length)) }
    guard r2 == Int(length) else { return }

    // Try to decode known requests
    var correlation: UUID?
    var result = Result(correlationID: correlation, status: "ok")
    if let req: SendRequest = try? FrameIO.decode(body) {
      correlation = req.correlationID
      result.correlationID = correlation
      do {
        try await Notifier.shared.post(payload: req.payload)
        result.status = "ok"
      } catch let notifierError as Notifier.Error {
        switch notifierError {
        case .notAuthorized:
          result.status = "not_authorized"
          result.message = "notifications not authorized"
        case .invalidAttachment(let message):
          result.status = "invalid_attachment"
          result.message = message
        case .runtime(let message):
          result.status = "runtime_error"
          result.message = message
        }
      } catch {
        result.status = "runtime_error"
        result.message = String(describing: error)
      }
    } else if let req: ListRequest = try? FrameIO.decode(body) {
      correlation = req.correlationID
      result.correlationID = correlation
      let tsv = try await Notifier.shared.list(group: req.group)
      result.status = "ok"
      result.message = tsv
    } else if let req: RemoveRequest = try? FrameIO.decode(body) {
      correlation = req.correlationID
      result.correlationID = correlation
      try await Notifier.shared.remove(group: req.group)
      result.status = "ok"
    }
    let ok = try FrameIO.encode(result)
    _ = ok.withUnsafeBytes { Darwin.write(cfd, $0.baseAddress, ok.count) }
  }
}

actor Notifier {
  enum Error: Swift.Error {
    case notAuthorized
    case invalidAttachment(String)
    case runtime(String)
  }
  static let shared = Notifier()

  func ensureAuthorized() async throws {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return
    case .denied:
      throw Error.notAuthorized
    case .notDetermined:
      let granted = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Swift.Error>) in
        center.requestAuthorization(options: [.alert, .sound]) { granted, err in
          if let err { cont.resume(throwing: err) } else { cont.resume(returning: granted) }
        }
      }
      if !granted { throw Error.notAuthorized }
    @unknown default:
      return
    }
  }

  func post(payload: NotificationPayload) async throws {
    try await ensureAuthorized()
    let center = UNUserNotificationCenter.current()

    // Group semantics: remove existing delivered with same group before posting
    if let gid = payload.groupID, !gid.isEmpty {
      let delivered = await center.deliveredNotifications()
      let ids = delivered.filter { $0.request.content.threadIdentifier == gid }.map { $0.request.identifier }
      if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
    }

    let content = UNMutableNotificationContent()
    content.title = payload.title
    if let subtitle = payload.subtitle { content.subtitle = subtitle }
    content.body = payload.message
    if let groupID = payload.groupID { content.threadIdentifier = groupID }
    if let snd = payload.sound {
      if snd == "default" {
        content.sound = .default
      } else {
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: snd))
      }
    }

    if let att = try await makeAttachmentIfNeeded(from: payload.contentImage) {
      content.attachments = [att]
    }

    switch payload.interruptionLevel {
    case .active: content.interruptionLevel = .active
    case .passive: content.interruptionLevel = .passive
    case .timeSensitive: content.interruptionLevel = .timeSensitive
    }

    let id = UUID().uuidString
    let req = UNNotificationRequest(
      identifier: id,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    )
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Swift.Error>) in
      UNUserNotificationCenter.current().add(req) { err in
        if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
      }
    }
  }

  func list(group: String) async throws -> String {
    let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
    let items = delivered.filter { notification in
      if group == "ALL" { return true }
      return notification.request.content.threadIdentifier == group
    }
    let rows = items.map { notification in
      let content = notification.request.content
      return "\(content.threadIdentifier)\t\(content.title)\t\(content.subtitle)\t\(content.body)\t\(notification.date)"
    }
    return "group\ttitle\tsubtitle\tmessage\tdeliveredAt\n" + rows.joined(separator: "\n")
  }

  func remove(group: String) async throws {
    let center = UNUserNotificationCenter.current()
    if group == "ALL" {
      center.removeAllDeliveredNotifications()
      return
    }
    let delivered = await center.deliveredNotifications()
    let ids = delivered.filter { $0.request.content.threadIdentifier == group }.map { $0.request.identifier }
    if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
  }

  private func makeAttachmentIfNeeded(from ref: String?) async throws -> UNNotificationAttachment? {
    guard let ref, !ref.isEmpty else { return nil }
    if ref.hasPrefix("http://") || ref.hasPrefix("https://") {
      // Fetch to a temp file
      guard let url = URL(string: ref) else { throw Error.invalidAttachment("invalid URL: \(ref)") }
      let (data, _) = try await URLSession.shared.data(from: url)
      let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(
        "img"
      )
      try data.write(to: tmp)
      return try UNNotificationAttachment(identifier: UUID().uuidString, url: tmp)
    } else if ref.hasPrefix("file://") {
      guard let url = URL(string: ref) else { throw Error.invalidAttachment("invalid file URL: \(ref)") }
      return try UNNotificationAttachment(identifier: UUID().uuidString, url: url)
    } else {
      let url = URL(fileURLWithPath: ref)
      return try UNNotificationAttachment(identifier: UUID().uuidString, url: url)
    }
  }
}
