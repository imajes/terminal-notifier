import Foundation

// Public validation error type used by CLI and tests
public enum TNValidationError: Error, Equatable, CustomStringConvertible {
  case invalidOpenURL(String)
  case attachmentNotFound(String)
  case attachmentTooLarge(String, Int64, Int64)
  case invalidWaitSeconds(Int)

  public var description: String {
    switch self {
    case .invalidOpenURL(let s):
      return "invalid --open URL: \(s)"
    case .attachmentNotFound(let path):
      return "content image not found: \(path)"
    case .attachmentTooLarge(let path, let size, let max):
      return "content image too large: \(path) (\(size) > \(max) bytes)"
    case .invalidWaitSeconds(let v):
      return "invalid --wait seconds: \(v)"
    }
  }
}

public enum Validation {
  // ~10 MB default limit for attachments
  public static let maxAttachmentSizeBytes: Int64 = 10 * 1024 * 1024

  public static func validate(_ payload: NotificationPayload) throws {
    // Validate --open URL if provided
    if let open = payload.openURL, !open.isEmpty {
      if let url = URL(string: open), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
        // ok
      } else if FileManager.default.fileExists(atPath: open) {
        // Treat as local path without scheme; allowed
      } else {
        throw TNValidationError.invalidOpenURL(open)
      }
    }

    // Validate content image if provided
    if let image = payload.contentImage, !image.isEmpty {
      if let url = URL(string: image), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
        // Remote URL allowed; size checked by shim at download time
      } else {
        // Local path must exist and be within size limit
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: image, isDirectory: &isDir)
        if !exists || isDir.boolValue {
          throw TNValidationError.attachmentNotFound(image)
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: image)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        if size > maxAttachmentSizeBytes {
          throw TNValidationError.attachmentTooLarge(image, size, maxAttachmentSizeBytes)
        }
      }
    }

    // Validate wait seconds when specified
    if let wait = payload.waitSeconds {
      if wait <= 0 { throw TNValidationError.invalidWaitSeconds(wait) }
    }
  }
}

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
    case .invalidOpenURL(let openURL):
      return "invalid --open URL: \(openURL)"
    case .attachmentNotFound(let path):
      return "content image not found: \(path)"
    case .attachmentTooLarge(let path, let size, let max):
      return "content image too large (\(size) > \(max) bytes): \(path)"
    case .invalidWaitSeconds(let value):
      return "invalid --wait value (must be > 0): \(value)"
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
    if let openURL = payload.openURL {
      guard let schemeRange = openURL.range(of: "://") else {
        throw TNValidationError.invalidOpenURL(openURL)
      }
      let scheme = String(openURL[..<schemeRange.lowerBound]).lowercased()
      let allowed = Set(["http", "https", "file"])
      if !allowed.contains(scheme) {
        throw TNValidationError.invalidOpenURL(openURL)
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
    if let wait = payload.waitSeconds, wait <= 0 {
      throw TNValidationError.invalidWaitSeconds(wait)
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
