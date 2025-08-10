import Foundation
import Core
import UMP

public enum Sysex7Status: UInt8 { case complete = 0x0, start = 0x1, cont = 0x2, end = 0x3 }

@inlinable public func sysex7Word(mt: UInt8 = 0x3, group: UInt8, status: Sysex7Status, bytes: [UInt8]) -> UMP32 {
    precondition(bytes.count <= 2)
    let num = UInt8(bytes.count)
    let b1 = (mt << 4) | (group & 0x0F)
    let b2 = (status.rawValue << 4) | (num & 0x0F)
    let d1 = bytes.count > 0 ? bytes[0] : 0
    let d2 = bytes.count > 1 ? bytes[1] : 0
    let w: UInt32 = (UInt32(b1) << 24) | (UInt32(b2) << 16) | (UInt32(d1) << 8) | UInt32(d2)
    return UMP32(w)
}

@inlinable public func sysex7Split(group: UInt8, payload: Data) -> [UMP32] {
    if payload.count == 0 { return [sysex7Word(group: group, status: .complete, bytes: [])] }
    if payload.count <= 2 { return [sysex7Word(group: group, status: .complete, bytes: [UInt8](payload))] }
    var out: [UMP32] = []
    var i = 0
    let bytes = [UInt8](payload)
    out.append(sysex7Word(group: group, status: .start, bytes: Array(bytes[i..<min(i+2, bytes.count)]))); i += 2
    while i + 2 < bytes.count {
        out.append(sysex7Word(group: group, status: .cont, bytes: Array(bytes[i..<i+2])))
        i += 2
    }
    out.append(sysex7Word(group: group, status: .end, bytes: Array(bytes[i..<min(i+2, bytes.count)])))
    return out
}

@inlinable public func sysex7Join(_ words: [UMP32], expectGroup: UInt8? = nil) -> Data? {
    guard !words.isEmpty else { return Data() }
    var acc = Data()
    var seenStart = false
    for (idx, w) in words.enumerated() {
        let b1 = UInt8((w.raw >> 24) & 0xFF)
        let b2 = UInt8((w.raw >> 16) & 0xFF)
        let mt = b1 >> 4
        let group = b1 & 0x0F
        if mt != 0x3 { return nil }
        if let g = expectGroup, g != group { return nil }
        let status = (b2 >> 4) & 0x0F
        let num = Int(b2 & 0x0F)
        let d1 = UInt8((w.raw >> 8) & 0xFF)
        let d2 = UInt8(w.raw & 0xFF)
        if num > 2 { return nil }
        switch status {
        case Sysex7Status.complete.rawValue:
            if words.count != 1 { return nil }
        case Sysex7Status.start.rawValue:
            if idx != 0 || seenStart { return nil }
            seenStart = true
        case Sysex7Status.cont.rawValue:
            if !seenStart || idx == 0 || idx == words.count - 1 { return nil }
        case Sysex7Status.end.rawValue:
            if !seenStart || idx != words.count - 1 { return nil }
        default: return nil
        }
        if num >= 1 { acc.append(d1) }
        if num == 2 { acc.append(d2) }
    }
    return acc
}

public enum Sysex8Status: UInt8 {
    case complete = 0x00, start = 0x11, cont = 0x22, end = 0x33
}

public struct UMP128: Equatable {
    public let w0: UInt32, w1: UInt32, w2: UInt32, w3: UInt32
    public init(_ w0: UInt32, _ w1: UInt32, _ w2: UInt32, _ w3: UInt32) { self.w0 = w0; self.w1 = w1; self.w2 = w2; self.w3 = w3 }
}

@inlinable public func sysex8Chunk(mt: UInt8 = 0x5, group: UInt8, status: Sysex8Status, streamID: UInt8, payload: [UInt8]) -> UMP128 {
    precondition(payload.count <= 12)
    let b1 = (mt << 4) | (group & 0x0F)
    let b2 = status.rawValue
    let b3 = streamID
    let b4 = UInt8(payload.count)
    func packWord(_ s: ArraySlice<UInt8>) -> UInt32 {
        var v: UInt32 = 0
        var i = 0
        for b in s {
            v |= UInt32(b) << (24 - (i * 8))
            i += 1
        }
        return v
    }
    let w1 = packWord(payload.prefix(4))
    let w2 = packWord(payload.dropFirst(4).prefix(4))
    let w3 = packWord(payload.dropFirst(8).prefix(4))
    let w0 = (UInt32(b1) << 24) | (UInt32(b2) << 16) | (UInt32(b3) << 8) | UInt32(b4)
    return UMP128(w0, w1, w2, w3)
}

@inlinable public func sysex8Split(group: UInt8, streamID: UInt8, payload: Data) -> [UMP128] {
    let bytes = [UInt8](payload)
    if bytes.count == 0 { return [sysex8Chunk(group: group, status: .complete, streamID: streamID, payload: [])] }
    var out: [UMP128] = []
    var i = 0
    let n = bytes.count
    let first = min(12, n - i); out.append(sysex8Chunk(group: group, status: .start, streamID: streamID, payload: Array(bytes[i..<i+first]))); i += first
    while i + 12 < n {
        out.append(sysex8Chunk(group: group, status: .cont, streamID: streamID, payload: Array(bytes[i..<i+12])))
        i += 12
    }
    let remain = n - i
    if remain > 0 {
        out.append(sysex8Chunk(group: group, status: .end, streamID: streamID, payload: Array(bytes[i..<n])))
    } else if n <= 12 {
        // special case: a single start must be complete instead
        out = [sysex8Chunk(group: group, status: .complete, streamID: streamID, payload: Array(bytes[0..<n]))]
    }
    return out
}

@inlinable public func sysex8Join(_ chunks: [UMP128], expectGroup: UInt8? = nil, expectStreamID: UInt8? = nil) -> Data? {
    guard !chunks.isEmpty else { return Data() }
    var acc = Data()
    var seenStart = false
    for (idx, c) in chunks.enumerated() {
        let b1 = UInt8((c.w0 >> 24) & 0xFF)
        let b2 = UInt8((c.w0 >> 16) & 0xFF)
        let b3 = UInt8((c.w0 >> 8) & 0xFF)
        let b4 = UInt8(c.w0 & 0xFF)
        let mt = b1 >> 4
        let group = b1 & 0x0F
        if mt != 0x5 { return nil }
        if let g = expectGroup, g != group { return nil }
        if let s = expectStreamID, s != b3 { return nil }
        switch b2 {
        case Sysex8Status.complete.rawValue:
            if chunks.count != 1 { return nil }
        case Sysex8Status.start.rawValue:
            if idx != 0 || seenStart { return nil }
            seenStart = true
        case Sysex8Status.cont.rawValue:
            if !seenStart || idx == 0 || idx == chunks.count - 1 { return nil }
        case Sysex8Status.end.rawValue:
            if !seenStart || idx != chunks.count - 1 { return nil }
        default: return nil
        }
        let bytes: [UInt8] = [
            UInt8((c.w1 >> 24) & 0xFF), UInt8((c.w1 >> 16) & 0xFF), UInt8((c.w1 >> 8) & 0xFF), UInt8(c.w1 & 0xFF),
            UInt8((c.w2 >> 24) & 0xFF), UInt8((c.w2 >> 16) & 0xFF), UInt8((c.w2 >> 8) & 0xFF), UInt8(c.w2 & 0xFF),
            UInt8((c.w3 >> 24) & 0xFF), UInt8((c.w3 >> 16) & 0xFF), UInt8((c.w3 >> 8) & 0xFF), UInt8(c.w3 & 0xFF)
        ]
        let n = Int(b4)
        if n > 12 { return nil }
        acc.append(contentsOf: bytes.prefix(n))
    }
    return acc
}
