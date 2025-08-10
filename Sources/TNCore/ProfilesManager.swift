import Foundation

public struct ProfileInfo: Codable, Equatable {
  public let name: String
  public let installed: Bool
  public let path: String
}

public enum ProfilesManager {
  public static let known: [String] = ["default", "codex", "buildbot"]

  public static func baseDir() -> URL {
    if let env = ProcessInfo.processInfo.environment["TN_PROFILES_DIR"], !env.isEmpty {
      return URL(fileURLWithPath: env)
    }
    // Keep within workspace by default
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return cwd.appendingPathComponent(".tn-profiles", isDirectory: true)
  }

  public static func list() throws -> [ProfileInfo] {
    try ensureBase()
    return known.map { name in
      let profileDir = baseDir().appendingPathComponent(name, isDirectory: true)
      let installed = FileManager.default.fileExists(atPath: profileDir.path)
      return ProfileInfo(name: name, installed: installed, path: profileDir.path)
    }
  }

  @discardableResult
  public static func install(name: String) throws -> ProfileInfo {
    try ensureBase()
    let profileDir = baseDir().appendingPathComponent(name, isDirectory: true)
    if !FileManager.default.fileExists(atPath: profileDir.path) {
      try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
      // Placeholder to indicate presence; real shim app comes in Step 5.
      let marker = profileDir.appendingPathComponent("shim.placeholder")
      FileManager.default.createFile(atPath: marker.path, contents: Data("shim".utf8))
    }
    return ProfileInfo(name: name, installed: true, path: profileDir.path)
  }

  @discardableResult
  public static func doctor(name: String?) throws -> String {
    let all = try self.list()
    guard let selectedName = name else {
      return all.map { "\($0.name)\tinstalled=\($0.installed)\tpath=\($0.path)" }.joined(separator: "\n")
    }
    guard let info = all.first(where: { $0.name == selectedName }) else {
      return "unknown profile: \(selectedName)"
    }
    return "\(info.name)\tinstalled=\(info.installed)\tpath=\(info.path)"
  }

  private static func ensureBase() throws {
    let dir = baseDir()
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
  }
}
