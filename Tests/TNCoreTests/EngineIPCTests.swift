import Foundation
import Testing
@testable import TNCore

@Suite struct EngineIPCTests {
  func makeSocketPath() -> String {
    let tmp = URL(fileURLWithPath: "/tmp")
    return tmp.appendingPathComponent("tn-ipc-\(UUID().uuidString)").path
  }

  func startServer(expect type: String, reply: @escaping (Int32, Data) -> Void, at path: String) throws -> (Thread, () -> Void)? {
    // Remove any existing file at path
    unlink(path)
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var addr = sockaddr_un()
    let cstr = path.utf8CString
    addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in _ = raw.initializeMemory(as: CChar.self, from: cstr) }
    let addrLen = socklen_t(MemoryLayout.offset(of: \sockaddr_un.sun_path)!) + socklen_t(cstr.count)
    let bindRes = withUnsafePointer(to: &addr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
        Darwin.bind(fd, sp, addrLen)
      }
    }
    guard bindRes == 0, Darwin.listen(fd, 1) == 0 else {
      Darwin.close(fd)
      return nil
    }

    let thread = Thread {
      var addr2 = sockaddr()
      var len: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
      let cfd = withUnsafeMutablePointer(to: &addr2) { ap in
        ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
          return Darwin.accept(fd, sp, &len)
        }
      }
      guard cfd >= 0 else { close(fd); return }
      // Read header and body
      var header = [UInt8](repeating: 0, count: 4)
      _ = header.withUnsafeMutableBytes { Darwin.read(cfd, $0.baseAddress, 4) }
      let length = header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
      var body = Data(count: Int(length))
      _ = body.withUnsafeMutableBytes { Darwin.read(cfd, $0.baseAddress, Int(length)) }
      reply(cfd, body)
      Darwin.close(cfd)
      Darwin.close(fd)
      unlink(path)
    }
    thread.start()
    return (thread, { Darwin.close(fd); unlink(path) })
  }

  @Test func engine_post_uses_ipc_when_env_set() async throws {
    let path = makeSocketPath()
    guard let (thread, cleanup) = try startServer(expect: "send", reply: { cfd, body in
      // Decode request
      let req: SendRequest = try! FrameIO.decode(body)
      #expect(!req.payload.message.isEmpty)
      // Reply ok
      let ok = try! FrameIO.encode(Result(correlationID: req.correlationID, status: "ok"))
      _ = ok.withUnsafeBytes { Darwin.write(cfd, $0.baseAddress, ok.count) }
    }, at: path) else {
      // Skip if sandbox prevents binding to /tmp
      return
    }
    defer { cleanup(); thread.cancel() }

    setenv("TN_SHIM_SOCKET", path, 1)
    defer { unsetenv("TN_SHIM_SOCKET") }

    let payload = NotificationPayload(title: "T", subtitle: nil, message: "M", groupID: nil, sound: nil, openURL: nil, execute: nil, activateBundleID: nil, contentImage: nil, senderProfile: nil, interruptionLevel: .active, waitSeconds: nil)
    try await Engine.post(payload: payload, logger: .init(label: "test"))
  }
}
