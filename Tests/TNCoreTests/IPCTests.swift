import Foundation
import Testing
@testable import TNCore

@Suite struct IPCTests {
  @Test func frame_round_trip_send_request() async throws {
    let payload = NotificationPayload(title: "T", subtitle: nil, message: "M", groupID: "g", sound: nil, openURL: nil, execute: nil, activateBundleID: nil, contentImage: nil, senderProfile: nil, interruptionLevel: .active, waitSeconds: nil)
    let req = SendRequest(payload: payload)
    let frame = try FrameIO.encode(req)
    // header length equals remaining bytes
    let len = frame.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    #expect(Int(len) == frame.count - 4)
    // decode
    let body = frame.suffix(from: 4)
    let decoded: SendRequest = try FrameIO.decode(body)
    #expect(decoded == req)
  }

  @Test func frame_accumulator_handles_partial_reads() async throws {
    let payload = NotificationPayload(title: "T2", subtitle: "S", message: "M2", groupID: nil, sound: "default", openURL: "https://example.com", execute: nil, activateBundleID: nil, contentImage: nil, senderProfile: nil, interruptionLevel: .active, waitSeconds: 5)
    let req = SendRequest(payload: payload)
    let f1 = try FrameIO.encode(req)
    let f2 = try FrameIO.encode(Result(correlationID: req.correlationID, status: "ok", message: nil))
    let stream = f1 + f2 // back-to-back frames as one continuous stream

    // Feed random chunk sizes
    var acc = FrameAccumulator()
    var pos = 0
    var decoded: [Any] = []
    while pos < stream.count {
      let chunkSize = min(Int.random(in: 1...7), stream.count - pos)
      let chunk = stream[pos..<(pos + chunkSize)]
      pos += chunkSize
      let frames = acc.feed(Data(chunk))
      for frame in frames {
        if decoded.isEmpty {
          let s: SendRequest = try FrameIO.decode(frame)
          decoded.append(s)
        } else {
          let r: Result = try FrameIO.decode(frame)
          decoded.append(r)
        }
      }
    }
    #expect(decoded.count == 2)
    #expect((decoded[0] as? SendRequest)?.payload.title == "T2")
    #expect((decoded[1] as? Result)?.status == "ok")
  }
}

