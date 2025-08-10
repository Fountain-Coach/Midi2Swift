import Foundation

/// Big-endian representation helpers.
@inlinable public func be32(_ x: UInt32) -> UInt32 { x.bigEndian }
@inlinable public func be64(_ x: UInt64) -> UInt64 { x.bigEndian }
@inlinable public func toHost32(_ x: UInt32) -> UInt32 { UInt32(bigEndian: x) }
@inlinable public func toHost64(_ x: UInt64) -> UInt64 { UInt64(bigEndian: x) }

public struct UMP32: Equatable, Hashable, CustomStringConvertible {
    public var raw: UInt32
    public init(_ raw: UInt32) { self.raw = raw }
    public var description: String { String(format: "0x%08X", raw) }
}

public struct UMP64: Equatable, Hashable, CustomStringConvertible {
    public var raw: UInt64
    public init(_ raw: UInt64) { self.raw = raw }
    public var description: String { String(format: "0x%016llX", raw) }
}

public struct UMP128: Equatable, Hashable, CustomStringConvertible {
    public var w0: UInt32, w1: UInt32, w2: UInt32, w3: UInt32
    public init(_ w0: UInt32, _ w1: UInt32, _ w2: UInt32, _ w3: UInt32) {
        self.w0 = w0; self.w1 = w1; self.w2 = w2; self.w3 = w3
    }
    public var description: String {
        String(format: "0x%08X%08X%08X%08X", w0, w1, w2, w3)
    }
}
