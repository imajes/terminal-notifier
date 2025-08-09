import Foundation
import Logging

public enum Engine {
  public static func post(payload: NotificationPayload, logger: Logger) async throws {
    if let sock = ProcessInfo.processInfo.environment["TN_SHIM_SOCKET"], !sock.isEmpty {
      // Use IPC when explicitly requested; throw on failure.
      let req = SendRequest(payload: payload)
      let result: Result = try IPCClient.roundTrip(socketPath: sock, request: req)
      guard result.status == "ok" else {
        throw NSError(
          domain: "tn",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: result.message ?? "error posting notification"]
        )
      }
      return
    } else {
      // Stub output for now.
      logger.info("POST \(payload.title) :: \(payload.message) (group=\(payload.groupID ?? "nil"))")
      FileHandle.standardOutput.write(
        ("posted\t\(payload.groupID ?? "")\t\(payload.title)\t\(payload.subtitle ?? "")\t\(payload.message)\n").data(
          using: .utf8
        )!
      )
    }
  }

  public static func list(group: String) async throws {
    if let sock = ProcessInfo.processInfo.environment["TN_SHIM_SOCKET"], !sock.isEmpty {
      let req = ListRequest(group: group)
      let result: Result = try IPCClient.roundTrip(socketPath: sock, request: req)
      guard result.status == "ok" else {
        throw NSError(
          domain: "tn",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: result.message ?? "error listing notifications"]
        )
      }
      // Server may return TSV in message
      if let msg = result.message { print(msg) }
    } else {
      print("group\ttitle\tsubtitle\tmessage\tdeliveredAt")
    }
  }

  public static func remove(group: String) async throws {
    if let sock = ProcessInfo.processInfo.environment["TN_SHIM_SOCKET"], !sock.isEmpty {
      let req = RemoveRequest(group: group)
      let result: Result = try IPCClient.roundTrip(socketPath: sock, request: req)
      guard result.status == "ok" else {
        throw NSError(
          domain: "tn",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: result.message ?? "error removing notifications"]
        )
      }
      return
    } else {
      fputs("removed\t\(group)\n", stderr)
    }
  }
}
