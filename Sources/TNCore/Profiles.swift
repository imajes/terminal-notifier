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
      let p = baseDir().appendingPathComponent(name, isDirectory: true)
      let installed = FileManager.default.fileExists(atPath: p.path)
      return ProfileInfo(name: name, installed: installed, path: p.path)
    }
  }

  @discardableResult
  public static func install(name: String) throws -> ProfileInfo {
    try ensureBase()
    let p = baseDir().appendingPathComponent(name, isDirectory: true)
    if !FileManager.default.fileExists(atPath: p.path) {
      try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
      // Placeholder to indicate presence; real shim app comes in Step 5.
      let marker = p.appendingPathComponent("shim.placeholder")
      FileManager.default.createFile(atPath: marker.path, contents: Data("shim".utf8))
    }
    return ProfileInfo(name: name, installed: true, path: p.path)
  }

  @discardableResult
  public static func doctor(name: String?) throws -> String {
    let list = try self.list()
    if let n = name {
      if let info = list.first(where: { $0.name == n }) {
        return "\(info.name)\tinstalled=\(info.installed)\tpath=\(info.path)"
      } else {
        return "unknown profile: \(n)"
      }
    } else {
      return list.map { "\($0.name)\tinstalled=\($0.installed)\tpath=\($0.path)" }.joined(separator: "\n")
    }
  }

  private static func ensureBase() throws {
    let dir = baseDir()
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
  }
}
