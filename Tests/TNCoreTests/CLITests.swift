import Foundation
import Testing

private enum TestErr: Error { case message(String) }

@Suite struct CLITests {
  func tnPath() throws -> String {
    let cwd = FileManager.default.currentDirectoryPath
    let candidates = [
      ".build/debug/tn",
      ".build/x86_64-apple-macosx/debug/tn",
      ".build/arm64-apple-macosx/debug/tn",
    ].map { URL(fileURLWithPath: cwd).appendingPathComponent($0).path }
    for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
      return p
    }
    throw TestErr.message("tn binary not found in .build; run `swift build` first.")
  }

  @discardableResult
  func runTN(_ args: [String], input: String? = nil) throws -> (exit: Int32, out: String, err: String) {
    let path = try tnPath()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: path)
    proc.arguments = args

    let outPipe = Pipe()
    proc.standardOutput = outPipe
    let errPipe = Pipe()
    proc.standardError = errPipe

    if let input {
      let inPipe = Pipe()
      proc.standardInput = inPipe
      try proc.run()
      inPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
      inPipe.fileHandleForWriting.closeFile()
    } else {
      try proc.run()
    }
    proc.waitUntilExit()

    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (proc.terminationStatus, out, err)
  }

  @Test func help_includes_subcommands_and_legacy() async throws {
    let r = try runTN(["--help"])
    #expect(r.exit == 0)
    #expect(r.out.contains("send"))
    // Root help should include legacy options declared at top level
    #expect(r.out.contains("message"))
  }

  @Test func version_and_help_shortcuts() async throws {
    let v = try runTN(["-version"])
    #expect(v.exit == 0)
    #expect(v.out.contains("0.1.0"))

    let h = try runTN(["-help"])
    #expect(h.exit == 0)
    #expect(h.out.contains("send"))
  }

  @Test func modern_send_message() async throws {
    let r = try runTN(["send", "--message", "Hello", "--title", "T"])
    #expect(r.exit == 0)
    #expect(r.out.contains("posted"))
    #expect(r.out.contains("Hello"))
  }

  @Test func legacy_send_message() async throws {
    let r = try runTN(["-message", "Hello", "-title", "T"])
    #expect(r.exit == 0)
    #expect(r.out.contains("posted"))
    #expect(r.out.contains("Hello"))
  }

  @Test func stdin_message() async throws {
    let r = try runTN([], input: "Hi from pipe\n")
    #expect(r.exit == 0)
    #expect(r.out.contains("posted"))
    #expect(r.out.contains("Hi from pipe"))
  }

  @Test func legacy_list_all_value() async throws {
    let r = try runTN(["-list", "ALL"])
    #expect(r.exit == 0)
    #expect(r.out.contains("group\t"))
  }

  @Test func legacy_remove_with_group_flag() async throws {
    let r = try runTN(["-remove", "-group", "foo"])
    #expect(r.exit == 0)
    #expect(r.err.contains("removed\tfoo"))
  }

  @Test func missing_message_exit2() async throws {
    // No args, no stdin content: process should exit usage error 2
    let r = try runTN(["send"], input: "")
    #expect(r.exit == 2)
    #expect(r.err.contains("message is required"))
  }

  @Test func invalid_interruption_level_exit2() async throws {
    let r = try runTN(["send", "--message", "ok", "--interruption-level", "bogus"])
    #expect(r.exit == 2)
    #expect(r.err.contains("invalid --interruption-level"))
  }

  @Test func invalid_open_url_exit2() async throws {
    let r = try runTN(["send", "--message", "ok", "--open", "foo://bar"])
    #expect(r.exit == 2)
    #expect(r.err.contains("invalid --open URL"))
  }

  @Test func missing_attachment_exit2() async throws {
    let r = try runTN(["send", "--message", "ok", "--content-image", "/no/such/file.png"])
    #expect(r.exit == 2)
    #expect(r.err.contains("content image not found"))
  }

  @Test func removed_ignoreDnD_is_error() async throws {
    let r = try runTN(["-ignoreDnD"])
    #expect(r.exit == 2)
    #expect(r.err.contains("removed"))
  }

  @Test func legacy_wait_option_parses() async throws {
    let r = try runTN(["-message", "ok", "-wait", "5"])
    #expect(r.exit == 0)
    #expect(r.out.contains("posted"))
  }
}
