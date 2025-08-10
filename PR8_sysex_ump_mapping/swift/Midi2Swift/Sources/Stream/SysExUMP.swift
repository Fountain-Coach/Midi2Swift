import Foundation
import Core

/// A lightweight, configurable mapper that wraps SysExSequencer pieces into UMP containers
/// without baking in spec constants. This keeps the code testable and deterministic while
/// we wire clause-backed constants from the matrix.
public struct SysExUMPMapper {
    public struct Config: Equatable {
        /// 4-bit Message Type field placed in the top nibble of Byte1.
        public var mt: UInt8
        /// 4-bit Group placed in the low nibble of Byte1.
        public var group: UInt8
        /// A 1-byte marker written in Byte2 to indicate piece kind (start/cont/end/complete).
        /// Tests can choose any values; later we will replace this with spec-backed constants.
        public var marker: (complete: UInt8, start: UInt8, cont: UInt8, end: UInt8)
        /// For SysEx8, a 1-byte stream identifier to be written in Byte3 of the first word.
        public var streamID: UInt8
        public init(mt: UInt8, group: UInt8, marker: (UInt8,UInt8,UInt8,UInt8), streamID: UInt8 = 0) {
            self.mt = mt
            self.group = group
            self.marker = (marker.0, marker.1, marker.2, marker.3)
            self.streamID = streamID
        }
    }

    public let cfg: Config
    public init(cfg: Config) { self.cfg = cfg }

    // MARK: SysEx7 (32-bit UMP words per segment)
    public func wrapSysEx7(_ piece: SysExStreamPiece) -> [UMP32] {
        switch piece {
        case .complete(let d): return pack7(marker: cfg.marker.complete, payload: d)
        case .start(let d):    return pack7(marker: cfg.marker.start,    payload: d)
        case .continue(let d): return pack7(marker: cfg.marker.cont,     payload: d)
        case .end(let d):      return pack7(marker: cfg.marker.end,      payload: d)
        }
    }

    // MARK: SysEx8 (128-bit UMP per segment)
    public func wrapSysEx8(_ piece: SysExStreamPiece) -> [UMP128] {
        switch piece {
        case .complete(let d): return pack8(marker: cfg.marker.complete, payload: d, stream: cfg.streamID)
        case .start(let d):    return pack8(marker: cfg.marker.start,    payload: d, stream: cfg.streamID)
        case .continue(let d): return pack8(marker: cfg.marker.cont,     payload: d, stream: cfg.streamID)
        case .end(let d):      return pack8(marker: cfg.marker.end,      payload: d, stream: cfg.streamID)
        }
    }

    // MARK: Decoders (inverse of the above)

    public func unwrapSysEx7(_ words: [UMP32]) -> SysExStreamPiece? {
        guard let first = words.first else { return nil }
        let b1 = UInt8((first.raw >> 24) & 0xFF) // (mt<<4)|group
        let b2 = UInt8((first.raw >> 16) & 0xFF) // marker
        let mt = b1 >> 4
        let group = b1 & 0x0F
        guard mt == cfg.mt, group == cfg.group else { return nil }
        let payload = extractPayload7(words)
        switch b2 {
        case cfg.marker.complete: return .complete(payload)
        case cfg.marker.start:    return .start(payload)
        case cfg.marker.cont:     return .continue(payload)
        case cfg.marker.end:      return .end(payload)
        default: return nil
        }
    }

    public func unwrapSysEx8(_ words: [UMP128]) -> SysExStreamPiece? {
        guard let first = words.first else { return nil }
        let b1 = UInt8((first.w0 >> 24) & 0xFF)
        let b2 = UInt8((first.w0 >> 16) & 0xFF)
        let b3 = UInt8((first.w0 >> 8) & 0xFF)  // stream id
        let mt = b1 >> 4
        let group = b1 & 0x0F
        guard mt == cfg.mt, group == cfg.group, b3 == cfg.streamID else { return nil }
        let payload = extractPayload8(words)
        switch b2 {
        case cfg.marker.complete: return .complete(payload)
        case cfg.marker.start:    return .start(payload)
        case cfg.marker.cont:     return .continue(payload)
        case cfg.marker.end:      return .end(payload)
        default: return nil
        }
    }

    // MARK: Packing helpers

    private func pack7(marker: UInt8, payload: Data) -> [UMP32] {
        // Each word: Byte1=(mt<<4|group), Byte2=marker, Byte3..4 = up to 2 payload bytes (big-endian packing here).
        var out: [UMP32] = []
        var i = 0
        let bytes = [UInt8](payload)
        while i < bytes.count {
            let b3 = (i < bytes.count) ? bytes[i] : 0
            let b4 = (i+1 < bytes.count) ? bytes[i+1] : 0
            let w = (UInt32(cfg.mt) << 28) | (UInt32(cfg.group) << 24) | (UInt32(marker) << 16) | (UInt32(b3) << 8) | UInt32(b4)
            out.append(UMP32(w))
            i += 2
        }
        // Special case: zero-length payload -> single header word
        if bytes.isEmpty {
            let w = (UInt32(cfg.mt) << 28) | (UInt32(cfg.group) << 24) | (UInt32(marker) << 16)
            out.append(UMP32(w))
        }
        return out
    }

    private func extractPayload7(_ words: [UMP32]) -> Data {
        var acc = Data()
        for w in words {
            let b3 = UInt8((w.raw >> 8) & 0xFF)
            let b4 = UInt8(w.raw & 0xFF)
            acc.append(b3)
            acc.append(b4)
        }
        return acc
    }

    private func pack8(marker: UInt8, payload: Data, stream: UInt8) -> [UMP128] {
        // 128-bit per segment: first word carries (mt|group, marker, streamID, lengthLow) then 12 bytes of payload
        // This is an agnostic layout for round-trip tests only.
        var out: [UMP128] = []
        var i = 0
        let bytes = [UInt8](payload)
        while i < bytes.count || (bytes.isEmpty && i == 0) {
            let remain = max(0, bytes.count - i)
            let n = min(12, remain)
            var w0: UInt32 = 0
            w0 |= UInt32(cfg.mt) << 28
            w0 |= UInt32(cfg.group) << 24
            w0 |= UInt32(marker) << 16
            w0 |= UInt32(stream) << 8
            w0 |= UInt32(n & 0xFF)
            var w1: UInt32 = 0
            var w2: UInt32 = 0
            var w3: UInt32 = 0
            let slice = bytes[i:i+n]
            func pack(_ idx: Int) -> UInt32 {
                var v: UInt32 = 0
                for k in 0..<4 {
                    let pos = idx + k
                    let b: UInt8 = (pos < slice.count) ? slice[pos] : 0
                    v |= UInt32(b) << (24 - (k*8))
                }
                return v
            }
            w1 = pack(0)
            w2 = pack(4)
            w3 = pack(8)
            out.append(UMP128(w0, w1, w2, w3))
            if n == 0 { break }
            i += n
        }
        return out
    }

    private func extractPayload8(_ words: [UMP128]) -> Data {
        var acc = Data()
        for w in words {
            let bytes: [UInt8] = [
                UInt8((w.w1 >> 24) & 0xFF), UInt8((w.w1 >> 16) & 0xFF),
                UInt8((w.w1 >> 8) & 0xFF),  UInt8(w.w1 & 0xFF),
                UInt8((w.w2 >> 24) & 0xFF), UInt8((w.w2 >> 16) & 0xFF),
                UInt8((w.w2 >> 8) & 0xFF),  UInt8(w.w2 & 0xFF),
                UInt8((w.w3 >> 24) & 0xFF), UInt8((w.w3 >> 16) & 0xFF),
                UInt8((w.w3 >> 8) & 0xFF),  UInt8(w.w3 & 0xFF)
            ]
            acc.append(contentsOf: bytes)
        }
        return acc
    }
}
