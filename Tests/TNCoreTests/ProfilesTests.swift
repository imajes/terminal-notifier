import Foundation
import Testing
@testable import TNCore

@Suite struct ProfilesTests {
  @Test func list_and_install_profile() async throws {
    // Use a temp dir for profiles
    let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".test-profiles-\(UUID().uuidString)")
    setenv("TN_PROFILES_DIR", dir.path, 1)
    defer { unsetenv("TN_PROFILES_DIR"); try? FileManager.default.removeItem(at: dir) }

    let before = try ProfilesManager.list()
    #expect(before.contains(where: { $0.name == "default" }))
    // Install
    let info = try ProfilesManager.install(name: "default")
    #expect(info.installed)
    let after = try ProfilesManager.list()
    #expect(after.first(where: { $0.name == "default" })?.installed == true)
  }
}

