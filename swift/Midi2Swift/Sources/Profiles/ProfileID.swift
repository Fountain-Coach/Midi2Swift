import Foundation

/// Opaque Profile Identifier container. Some profiles use 32-bit IDs, others may use longer identifiers.
/// We model two forms: 32-bit and 128-bit opaque values with hex formatting. Specific structure
/// (e.g., namespaces) will be wired from spec tables in later PRs.
public enum ProfileID: Equatable, Hashable, CustomStringConvertible {
    case u32(UInt32)
    case u128(UUID)

    public var description: String {
        switch self {
        case .u32(let v): return String(format: "0x%08X", v)
        case .u128(let u): return u.uuidString.uppercased()
        }
    }

    public init?(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count == 10, s.hasPrefix("0x"), let v = UInt32(s.dropFirst(2), radix: 16) {
            self = .u32(v)
            return
        }
        if let u = UUID(uuidString: s) {
            self = .u128(u)
            return
        }
        return nil
    }

    public func toBytes() -> [UInt8] {
        switch self {
        case .u32(let v):
            return [
                UInt8((v >> 24) & 0xFF),
                UInt8((v >> 16) & 0xFF),
                UInt8((v >> 8) & 0xFF),
                UInt8(v & 0xFF)
            ]
        case .u128(let u):
            var uuid = u.uuid
            // UUID bytes are big-endian in textual form; return raw network order.
            return withUnsafeBytes(of: &uuid) { Array($0) }
        }
    }
}
