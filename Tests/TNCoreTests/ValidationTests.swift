import Foundation
import Testing

@testable import TNCore

@Suite struct ValidationTests {
  func tmpFile(size: Int) throws -> String {
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent(UUID().uuidString)
    let data = Data(count: size)
    try data.write(to: url)
    return url.path
  }

  @Test func openURL_scheme_validation() async throws {
    let good = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: "https://example.com",
      execute: nil,
      activateBundleID: nil,
      contentImage: nil,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: nil
    )
    try Validation.validate(good)

    let bad = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: "foo://bar",
      execute: nil,
      activateBundleID: nil,
      contentImage: nil,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: nil
    )
    var threw = false
    do { try Validation.validate(bad) } catch let e as TNValidationError {
      threw = true
      #expect(e == .invalidOpenURL("foo://bar"))
    }
    #expect(threw)
  }

  @Test func content_image_local_checks() async throws {
    // Small file ok
    let smallPath = try tmpFile(size: 1024)
    let p1 = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: nil,
      execute: nil,
      activateBundleID: nil,
      contentImage: smallPath,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: nil
    )
    try Validation.validate(p1)

    // Missing file
    let missingPath = smallPath + ".missing"
    let p2 = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: nil,
      execute: nil,
      activateBundleID: nil,
      contentImage: missingPath,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: nil
    )
    var threwMissing = false
    do { try Validation.validate(p2) } catch let e as TNValidationError {
      threwMissing = true
      switch e {
      case .attachmentNotFound(let path): #expect(path == missingPath)
      default: #expect(false)
      }
    }
    #expect(threwMissing)

    // Too large
    let bigSize = Int(Validation.maxAttachmentSizeBytes + 1)
    let bigPath = try tmpFile(size: bigSize)
    let p3 = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: nil,
      execute: nil,
      activateBundleID: nil,
      contentImage: bigPath,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: nil
    )
    var threwLarge = false
    do { try Validation.validate(p3) } catch let e as TNValidationError {
      threwLarge = true
      switch e {
      case .attachmentTooLarge(let path, _, _): #expect(path == bigPath)
      default: #expect(false)
      }
    }
    #expect(threwLarge)
  }

  @Test func wait_seconds_validation() async throws {
    let bad = NotificationPayload(
      title: "T",
      subtitle: nil,
      message: "M",
      groupID: nil,
      sound: nil,
      openURL: nil,
      execute: nil,
      activateBundleID: nil,
      contentImage: nil,
      senderProfile: nil,
      interruptionLevel: .active,
      waitSeconds: 0
    )
    var threwWait = false
    do { try Validation.validate(bad) } catch let e as TNValidationError {
      threwWait = true
      switch e {
      case .invalidWaitSeconds(let v): #expect(v == 0)
      default: #expect(false)
      }
    }
    #expect(threwWait)
  }
}
