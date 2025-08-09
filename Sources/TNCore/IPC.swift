import Foundation

/// Request sent to the shim to post a notification.
public struct SendRequest: Codable, Equatable {
  public var correlationID: UUID
  public var payload: NotificationPayload

  public init(correlationID: UUID = UUID(), payload: NotificationPayload) {
    self.correlationID = correlationID
    self.payload = payload
  }
}

/// Request to list delivered notifications.
public struct ListRequest: Codable, Equatable {
  public var correlationID: UUID
  public var group: String  // specific group or ALL

  public init(correlationID: UUID = UUID(), group: String) {
    self.correlationID = correlationID
    self.group = group
  }
}

/// Request to remove delivered notifications.
public struct RemoveRequest: Codable, Equatable {
  public var correlationID: UUID
  public var group: String  // specific group or ALL

  public init(correlationID: UUID = UUID(), group: String) {
    self.correlationID = correlationID
    self.group = group
  }
}

/// Generic result returned from the shim.
public struct Result: Codable, Equatable {
  public var correlationID: UUID?
  public var status: String  // "ok" or error code string
  public var message: String?

  public init(correlationID: UUID?, status: String, message: String? = nil) {
    self.correlationID = correlationID
    self.status = status
    self.message = message
  }
}

/// Framing helpers for the IPC protocol: `u32 length (BE)` + JSON payload.
public enum FrameIO {
  /// Encodes the given Codable value into a length-prefixed JSON frame.
  public static func encode<T: Encodable>(_ value: T) throws -> Data {
    let payload = try JSONEncoder().encode(value)
    var buf = Data()
    var len = UInt32(payload.count).bigEndian
    withUnsafeBytes(of: &len) { buf.append(contentsOf: $0) }
    buf.append(payload)
    return buf
  }

  /// Decodes a JSON payload (no length header) into the requested type.
  public static func decode<T: Decodable>(_ payload: Data, as: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: payload)
  }
}

/// Incremental frame accumulator useful for partial reads.
public struct FrameAccumulator {
  private var buffer = Data()

  public init() {}

  /// Feeds a new chunk and returns any complete payloads available after parsing
  /// one or more `[len][json]` frames from the internal buffer.
  public mutating func feed(_ chunk: Data) -> [Data] {
    buffer.append(chunk)
    var payloads: [Data] = []

    while true {
      guard buffer.count >= 4 else { break }
      let lenBE = buffer.prefix(4)
      let length = lenBE.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
      let total = 4 + Int(length)
      guard buffer.count >= total else { break }
      let payload = buffer.subdata(in: 4..<total)
      payloads.append(payload)
      buffer.removeSubrange(0..<total)
    }
    return payloads
  }
}

// MARK: - Simple IPC client (Unix domain socket)

public enum IPCError: Error, CustomStringConvertible {
  case socketCreationFailed(errno: Int32)
  case connectFailed(errno: Int32, path: String)
  case writeFailed(errno: Int32)
  case readFailed(errno: Int32)
  case shortRead
  case decodeFailed(String)

  public var description: String {
    switch self {
    case .socketCreationFailed(let e): return "socket() failed: errno=\(e)"
    case .connectFailed(let e, let p): return "connect(\(p)) failed: errno=\(e)"
    case .writeFailed(let e): return "write() failed: errno=\(e)"
    case .readFailed(let e): return "read() failed: errno=\(e)"
    case .shortRead: return "short read"
    case .decodeFailed(let m): return "decode failed: \(m)"
    }
  }
}

public enum IPCClient {
  /// Sends a Codable request and waits for a Decodable response using the length-prefixed JSON frame protocol.
  public static func roundTrip<Req: Encodable, Res: Decodable>(
    socketPath: String,
    request: Req
  ) throws -> Res {
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    if fd < 0 { throw IPCError.socketCreationFailed(errno: errno) }
    defer { Darwin.close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
    let pathData = socketPath.utf8CString
    if pathData.count > maxLen {
      throw IPCError.connectFailed(errno: ENAMETOOLONG, path: socketPath)
    }
    withUnsafeMutableBytes(of: &addr.sun_path) { rawBuf in
      _ = rawBuf.initializeMemory(as: CChar.self, from: pathData)
    }
    var rawAddr = sockaddr()
    memcpy(&rawAddr, &addr, MemoryLayout<sockaddr_un>.size)
    let res = withUnsafePointer(to: &addr) { ptr -> Int32 in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
        Darwin.connect(fd, sp, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    if res != 0 { throw IPCError.connectFailed(errno: errno, path: socketPath) }

    // Write frame
    let frame = try FrameIO.encode(request)
    try writeAll(fd: fd, data: frame)

    // Read header
    let header = try readN(fd: fd, n: 4)
    let len = header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    let body = try readN(fd: fd, n: Int(len))
    do {
      return try FrameIO.decode(body)
    } catch {
      throw IPCError.decodeFailed(String(describing: error))
    }
  }

  private static func writeAll(fd: Int32, data: Data) throws {
    var written = 0
    try data.withUnsafeBytes { (bufRaw: UnsafeRawBufferPointer) in
      while written < data.count {
        let p = bufRaw.baseAddress!.advanced(by: written)
        let n = Darwin.write(fd, p, data.count - written)
        if n < 0 { throw IPCError.writeFailed(errno: errno) }
        written += n
      }
    }
  }

  private static func readN(fd: Int32, n: Int) throws -> Data {
    var out = Data()
    out.reserveCapacity(n)
    var remaining = n
    var buffer = [UInt8](repeating: 0, count: max(remaining, 4096))
    while remaining > 0 {
      let toRead = min(remaining, buffer.count)
      let r = buffer.withUnsafeMutableBytes { ptr in
        Darwin.read(fd, ptr.baseAddress, toRead)
      }
      if r < 0 { throw IPCError.readFailed(errno: errno) }
      if r == 0 { throw IPCError.shortRead }
      out.append(buffer, count: r)
      remaining -= r
    }
    return out
  }
}
