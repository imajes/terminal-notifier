import Foundation

/// Errors that may occur while validating a notification payload.
public enum TNValidationError: Error, CustomStringConvertible, Equatable {
  case emptyMessage
  case invalidOpenURL(String)
  case attachmentNotFound(String)
  case attachmentTooLarge(path: String, size: Int64, max: Int64)
  case invalidWaitSeconds(Int)

  public var description: String {
    switch self {
    case .emptyMessage:
      return "message is required (use --message or pipe stdin)"
    case .invalidOpenURL(let s):
      return "invalid --open URL: \(s)"
    case .attachmentNotFound(let p):
      return "content image not found: \(p)"
    case .attachmentTooLarge(let path, let size, let max):
      return "content image too large (\(size) > \(max) bytes): \(path)"
    case .invalidWaitSeconds(let v):
      return "invalid --wait value (must be > 0): \(v)"
    }
  }
}

/// Validation utilities for TNCore models.
public enum Validation {
  /// Maximum allowed attachment size in bytes (~10MB).
  public static let maxAttachmentSizeBytes: Int64 = 10 * 1024 * 1024

  /// Validate a payload for basic correctness before posting.
  /// - Throws: `TNValidationError` for invalid inputs.
  public static func validate(_ payload: NotificationPayload) throws {
    // Message
    let trimmed = payload.message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw TNValidationError.emptyMessage }

    // Open URL
    if let s = payload.openURL {
      guard let schemeRange = s.range(of: "://") else {
        throw TNValidationError.invalidOpenURL(s)
      }
      let scheme = String(s[..<schemeRange.lowerBound]).lowercased()
      let allowed = Set(["http", "https", "file"])
      if !allowed.contains(scheme) {
        throw TNValidationError.invalidOpenURL(s)
      }
    }

    // Attachment
    if let ci = payload.contentImage, !ci.isEmpty {
      if ci.hasPrefix("http://") || ci.hasPrefix("https://") {
        // Remote URL allowed; shim may download later.
      } else if ci.hasPrefix("file://") {
        guard let url = URL(string: ci), url.isFileURL else {
          throw TNValidationError.attachmentNotFound(ci)
        }
        try validateLocalAttachment(atPath: url.path)
      } else {
        // Treat as local path.
        try validateLocalAttachment(atPath: ci)
      }
    }

    // Wait seconds
    if let w = payload.waitSeconds, w <= 0 {
      throw TNValidationError.invalidWaitSeconds(w)
    }
  }

  private static func validateLocalAttachment(atPath path: String) throws {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
      throw TNValidationError.attachmentNotFound(path)
    }
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    if let size = attrs[.size] as? NSNumber {
      let int64 = size.int64Value
      if int64 > maxAttachmentSizeBytes {
        throw TNValidationError.attachmentTooLarge(path: path, size: int64, max: maxAttachmentSizeBytes)
      }
    }
  }
}
