import Foundation

public enum InterruptionLevel: String, Codable {
  case passive, active, timeSensitive
  public init?(from s: String?) {
    guard let s = s else { return nil }
    self.init(rawValue: s)
  }
}

public struct NotificationPayload: Codable {
  public var title: String
  public var subtitle: String?
  public var message: String
  public var groupID: String?
  public var sound: String?
  public var openURL: String?
  public var execute: String?
  public var activateBundleID: String?
  public var contentImage: String?
  public var senderProfile: String?
  public var interruptionLevel: InterruptionLevel
  public var waitSeconds: Int?

  public init(title: String, subtitle: String?, message: String, groupID: String?, sound: String?, openURL: String?, execute: String?, activateBundleID: String?, contentImage: String?, senderProfile: String?, interruptionLevel: InterruptionLevel, waitSeconds: Int?) {
    self.title = title
    self.subtitle = subtitle
    self.message = message
    self.groupID = groupID
    self.sound = sound
    self.openURL = openURL
    self.execute = execute
    self.activateBundleID = activateBundleID
    self.contentImage = contentImage
    self.senderProfile = senderProfile
    self.interruptionLevel = interruptionLevel
    self.waitSeconds = waitSeconds
  }
}
