import Foundation

/// Error codes defined by JSON-RPC 2.0 and the A2A protocol (spec §5.4).
public enum A2AErrorCode: Int, Sendable, Codable, CaseIterable {
    // Standard JSON-RPC 2.0 codes.
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603

    // A2A-specific codes.
    case taskNotFound = -32001
    case taskNotCancelable = -32002
    case pushNotificationNotSupported = -32003
    case unsupportedOperation = -32004
    case contentTypeNotSupported = -32005
    case invalidAgentResponse = -32006
    case extendedAgentCardNotConfigured = -32007
    case extensionSupportRequired = -32008
    case versionNotSupported = -32009

    /// The default human-readable message for this code.
    public var defaultMessage: String {
        switch self {
        case .parseError: return "Invalid JSON payload"
        case .invalidRequest: return "Request payload validation error"
        case .methodNotFound: return "Method not found"
        case .invalidParams: return "Invalid parameters"
        case .internalError: return "Internal error"
        case .taskNotFound: return "Task not found"
        case .taskNotCancelable: return "Task cannot be canceled"
        case .pushNotificationNotSupported: return "Push Notification is not supported"
        case .unsupportedOperation: return "This operation is not supported"
        case .contentTypeNotSupported: return "Incompatible content types"
        case .invalidAgentResponse: return "Invalid agent response"
        case .extendedAgentCardNotConfigured: return "Extended agent card not configured"
        case .extensionSupportRequired: return "Extension support required"
        case .versionNotSupported: return "Protocol version not supported"
        }
    }
}

/// An A2A protocol error, mapping to a JSON-RPC error object.
public struct A2AError: Error, Sendable, Equatable {
    /// The numeric error code. Usually one of `A2AErrorCode`, but unknown
    /// codes from a server are preserved as-is.
    public var code: Int
    /// A short human-readable summary of the error.
    public var message: String
    /// Additional error detail (spec §5.4: an array of objects each carrying `@type`).
    public var data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(_ code: A2AErrorCode, message: String? = nil, data: JSONValue? = nil) {
        self.code = code.rawValue
        self.message = message ?? code.defaultMessage
        self.data = data
    }

    /// The well-known error code, if this error's code is one.
    public var errorCode: A2AErrorCode? {
        A2AErrorCode(rawValue: code)
    }

    /// The JSON-RPC error object for this error.
    public var errorObject: JSONRPCErrorObject {
        JSONRPCErrorObject(code: code, message: message, data: data)
    }

    public init(_ errorObject: JSONRPCErrorObject) {
        self.code = errorObject.code
        self.message = errorObject.message
        self.data = errorObject.data
    }
}

extension A2AError: CustomStringConvertible {
    public var description: String {
        "A2AError(\(code)): \(message)"
    }
}
