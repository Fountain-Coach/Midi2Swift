import Foundation

/// SysEx7/8 stream piece type (generic, container-agnostic).
public enum SysExStreamPiece: Equatable {
    case complete(Data)           // fits in one packet
    case start(Data)              // first segment
    case `continue`(Data)         // continuation segment
    case end(Data)                // final segment
}

public enum SysExChunkingMode {
    case sysex7(maxPayload: Int)
    case sysex8(maxPayload: Int)
}

/// A small utility that splits arbitrary SysEx payloads into segment pieces and can reassemble them.
/// NOTE: This is transport/container-agnostic; mapping to UMP words is handled elsewhere.
public struct SysExSequencer {
    public let mode: SysExChunkingMode
    public init(mode: SysExChunkingMode) { self.mode = mode }

    /// Split a full SysEx payload into pieces according to the selected mode's max payload.
    public func split(_ payload: Data) -> [SysExStreamPiece] {
        let maxPayload: Int
        switch mode {
        case .sysex7(let m): maxPayload = max(1, m)
        case .sysex8(let m): maxPayload = max(1, m)
        }
        if payload.count <= maxPayload {
            return [.complete(payload)]
        }
        var out: [SysExStreamPiece] = []
        var i = 0
        let bytes = [UInt8](payload)
        // start
        let firstEnd = min(maxPayload, bytes.count)
        out.append(.start(Data(bytes[i..<firstEnd])))
        i = firstEnd
        // continue
        while i + maxPayload < bytes.count {
            let j = i + maxPayload
            out.append(.continue(Data(bytes[i..<j])))
            i = j
        }
        // end
        if i < bytes.count {
            out.append(.end(Data(bytes[i..<bytes.count])))
        }
        return out
    }

    /// Reassemble pieces back into the original payload. Returns nil if the sequence is invalid.
    public func join(_ pieces: [SysExStreamPiece]) -> Data? {
        guard !pieces.isEmpty else { return Data() }
        var acc = Data()
        var expecting: Expect = .any
        for (idx, p) in pieces.enumerated() {
            switch p {
            case .complete(let d):
                if pieces.count != 1 { return nil }
                return d
            case .start(let d):
                if expecting != .any { return nil }
                acc.append(d)
                expecting = .contOrEnd
            case .continue(let d):
                if expecting != .contOrEnd { return nil }
                acc.append(d)
            case .end(let d):
                if expecting == .any && idx != pieces.count - 1 { return nil }
                acc.append(d)
                expecting = .done
            }
        }
        return expecting == .done ? acc : nil
    }

    private enum Expect { case any, contOrEnd, done }
}
