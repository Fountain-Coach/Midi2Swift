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
    case offerSent
    case negotiated
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
    case discoveryStart
    case discoveryReply(remoteMUID: UInt32)
    case protocolStart
    case protocolAccept
    case timeout
    case error
}

@inlinable
public func ciReduce(_ s: CIState, _ e: CIEvent) -> (CIState, [CIAffect]) {
    switch (s.mode, e) {

    // Discovery
    case (.idle, .discoveryStart):
        var probe = Data([0x7E, 0x7F])
        probe.append(contentsOf: withUnsafeBytes(of: s.localMUID.bigEndian, Array.init))
        return (CIState(mode: .probeSent, localMUID: s.localMUID, remoteMUID: nil), [.sendSysEx(probe), .timer(ms: 200)])

    case (.probeSent, .discoveryReply(let rmuid)):
        return (CIState(mode: .discovered, localMUID: s.localMUID, remoteMUID: rmuid), [.none])

    case (.probeSent, .timeout):
        return (CIState(mode: .failed, localMUID: s.localMUID, remoteMUID: nil), [.none])

    // Protocol Negotiation
    case (.discovered, .protocolStart), (.idle, .protocolStart):
        var offer = Data([0x7E, 0x01]) // placeholder header bytes
        offer.append(contentsOf: withUnsafeBytes(of: s.localMUID.bigEndian, Array.init))
        return (CIState(mode: .offerSent, localMUID: s.localMUID, remoteMUID: s.remoteMUID), [.sendSysEx(offer), .timer(ms: 200)])

    case (.offerSent, .protocolAccept):
        return (CIState(mode: .negotiated, localMUID: s.localMUID, remoteMUID: s.remoteMUID), [.none])

    case (_, .error):
        return (CIState(mode: .failed, localMUID: s.localMUID, remoteMUID: s.remoteMUID), [.none])

    default:
        return (s, [.none])
    }
}
