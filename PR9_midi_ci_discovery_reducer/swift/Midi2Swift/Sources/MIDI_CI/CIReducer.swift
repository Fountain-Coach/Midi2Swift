import Foundation

public enum CIAffect: Equatable {
    case none
    case sendSysEx(Data)
    case timer(ms: Int)
}

public enum CIStateMode: Equatable {
    case idle
    case probeSent
    case discovered
    case failed
}

public struct CIState: Equatable {
    public var mode: CIStateMode
    public var localMUID: UInt32
    public var remoteMUID: UInt32?
    public init(mode: CIStateMode = .idle, localMUID: UInt32 = 0x0000_0001, remoteMUID: UInt32? = nil) {
        self.mode = mode
        self.localMUID = localMUID
        self.remoteMUID = remoteMUID
    }
}

public enum CIEvent: Equatable {
    case startDiscovery
    case discoveryReply(remoteMUID: UInt32)
    case timeout
    case error
}

/// Simple, spec-agnostic reducer for Discovery. Will be replaced by codegen once matrix has full CI flows.
@inlinable
public func ciReduce(_ s: CIState, _ e: CIEvent) -> (CIState, [CIAffect]) {
    switch (s.mode, e) {
    case (.idle, .startDiscovery):
        // Emit a discovery SysEx with our local MUID. Not spec bytes (placeholder framing).
        var msg = Data([0x7E, 0x7F]) // arbitrary header placeholder
        msg.append(contentsOf: withUnsafeBytes(of: s.localMUID.bigEndian, Array.init))
        return (CIState(mode: .probeSent, localMUID: s.localMUID, remoteMUID: nil), [.sendSysEx(msg), .timer(ms: 200)])
    case (.probeSent, .discoveryReply(let rmuid)):
        return (CIState(mode: .discovered, localMUID: s.localMUID, remoteMUID: rmuid), [.none])
    case (.probeSent, .timeout):
        return (CIState(mode: .failed, localMUID: s.localMUID, remoteMUID: nil), [.none])
    case (_, .error):
        return (CIState(mode: .failed, localMUID: s.localMUID, remoteMUID: nil), [.none])
    default:
        return (s, [.none])
    }
}
