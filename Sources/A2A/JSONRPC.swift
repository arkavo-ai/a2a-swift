import Foundation

/// A2A protocol constants.
public enum A2AProtocol {
    /// The protocol version this SDK implements.
    public static let version = "1.0"

    /// The well-known path where an agent card is published (RFC 8615).
    public static let agentCardWellKnownPath = "/.well-known/agent-card.json"
}

/// HTTP header names used by the A2A protocol (spec §9.2 service parameters).
///
/// Multi-valued headers (`A2A-Extensions`) are comma-separated.
public enum A2AHTTPHeader {
    /// Carries the A2A protocol version of the request, e.g. "1.0".
    public static let version = "A2A-Version"
    /// Comma-separated list of extension URIs activated for the request/response.
    public static let extensions = "A2A-Extensions"
}

/// JSON-RPC method names for the A2A protocol (spec §5.3).
///
/// A2A v1.0 uses PascalCase method names identical to the gRPC service methods.
public enum A2AMethod {
    public static let sendMessage = "SendMessage"
    public static let sendStreamingMessage = "SendStreamingMessage"
    public static let getTask = "GetTask"
    public static let listTasks = "ListTasks"
    public static let cancelTask = "CancelTask"
    public static let subscribeToTask = "SubscribeToTask"
    public static let createTaskPushNotificationConfig = "CreateTaskPushNotificationConfig"
    public static let getTaskPushNotificationConfig = "GetTaskPushNotificationConfig"
    public static let listTaskPushNotificationConfigs = "ListTaskPushNotificationConfigs"
    public static let deleteTaskPushNotificationConfig = "DeleteTaskPushNotificationConfig"
    public static let getExtendedAgentCard = "GetExtendedAgentCard"

    /// All A2A method names.
    public static let all: [String] = [
        sendMessage, sendStreamingMessage, getTask, listTasks, cancelTask, subscribeToTask,
        createTaskPushNotificationConfig, getTaskPushNotificationConfig,
        listTaskPushNotificationConfigs, deleteTaskPushNotificationConfig, getExtendedAgentCard,
    ]

    /// Method names whose responses are streamed as Server-Sent Events.
    public static let streaming: Set<String> = [sendStreamingMessage, subscribeToTask]
}

/// A JSON-RPC 2.0 request identifier: a string, a number, or null.
public enum JSONRPCID: Sendable, Codable, Hashable, CustomStringConvertible {
    case string(String)
    case number(Int64)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int64.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSON-RPC id must be a string, number, or null"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var description: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .null: return "null"
        }
    }
}

extension JSONRPCID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONRPCID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) { self = .number(value) }
}

/// A JSON-RPC 2.0 request envelope.
public struct JSONRPCRequest<Params: Codable & Sendable>: Sendable, Codable {
    /// Always "2.0".
    public var jsonrpc: String
    /// The request identifier. Absent for notifications.
    public var id: JSONRPCID?
    /// The method name, e.g. `SendMessage`.
    public var method: String
    /// The method parameters.
    public var params: Params?

    public init(id: JSONRPCID?, method: String, params: Params?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// The error member of a JSON-RPC 2.0 response.
public struct JSONRPCErrorObject: Sendable, Codable, Equatable {
    /// The error code (see `A2AErrorCode` for A2A-specific codes).
    public var code: Int
    /// A short human-readable summary of the error.
    public var message: String
    /// Additional error detail. Per the A2A spec this is an array of objects
    /// each carrying an `@type` key (e.g. `google.rpc.ErrorInfo`), but any
    /// JSON value is preserved.
    public var data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// A JSON-RPC 2.0 response envelope.
public struct JSONRPCResponse<Result: Codable & Sendable>: Sendable, Codable {
    /// Always "2.0".
    public var jsonrpc: String
    /// The identifier of the request this responds to (null if it could not be determined).
    public var id: JSONRPCID
    /// The result, present on success.
    public var result: Result?
    /// The error, present on failure.
    public var error: JSONRPCErrorObject?

    public init(id: JSONRPCID, result: Result?, error: JSONRPCErrorObject? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }
}
