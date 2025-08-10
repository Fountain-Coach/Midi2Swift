import Foundation

/// Property Exchange minimal header model (spec-agnostic scaffolding).
/// Exact field/value mapping will be code-generated from the matrix in later PRs.
public enum PEStatus: Equatable, Hashable, CustomStringConvertible {
    case code(Int)

    public var description: String {
        switch self {
        case .code(let c): return "PEStatus(\(c))"
        }
    }

    public var codeValue: Int {
        switch self {
        case .code(let c): return c
        }
    }

    public var isSuccess: Bool { (200...299).contains(codeValue) }
    public var isClientError: Bool { (400...499).contains(codeValue) }
    public var isServerError: Bool { (500...599).contains(codeValue) }
}

public struct PERequestHeader: Equatable, Hashable {
    public var resource: String      // e.g., "identity", "profile-list"
    public var version: String       // e.g., "1.0"
    public var contentType: String   // e.g., "application/json"
    public init(resource: String, version: String, contentType: String) {
        self.resource = resource
        self.version = version
        self.contentType = contentType
    }
}

public struct PEReplyHeader: Equatable, Hashable {
    public var status: PEStatus
    public var reason: String?
    public var version: String
    public init(status: PEStatus, reason: String?, version: String) {
        self.status = status
        self.reason = reason
        self.version = version
    }
}
