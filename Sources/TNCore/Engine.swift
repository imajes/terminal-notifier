import Foundation
import Logging

public enum Engine {
  public static func post(payload: NotificationPayload, logger: Logger) async throws {
    // Stub: This is where IPC to the shim would happen,
    // or a minimal osascript fallback if no shim is installed.
    logger.info("POST \(payload.title) :: \(payload.message) (group=\(payload.groupID ?? "nil"))")
    // For now, just print TSV-like confirmation
    FileHandle.standardOutput.write(("posted\t\(payload.groupID ?? "")\t\(payload.title)\t\(payload.subtitle ?? "")\t\(payload.message)\n").data(using: .utf8)!)
  }

  public static func list(group: String) async throws {
    // Stub
    print("group\ttitle\tsubtitle\tmessage\tdeliveredAt")
  }

  public static func remove(group: String) async throws {
    // Stub
    fputs("removed\t\(group)\n", stderr)
  }
}
