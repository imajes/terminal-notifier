import Testing
@testable import TNCore

@Test func payload_init() async throws {
  let p = NotificationPayload(title: "T", subtitle: nil, message: "M", groupID: nil, sound: nil, openURL: nil, execute: nil, activateBundleID: nil, contentImage: nil, senderProfile: nil, interruptionLevel: .active, waitSeconds: nil)
  #expect(p.title == "T")
}
