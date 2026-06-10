import A2A
import Foundation

/// Routes JSON-RPC request bodies to an `A2ARequestHandler` and encodes the
/// responses, independent of any HTTP server.
///
/// Wire this into the HTTP framework of your choice: pass the request body to
/// `dispatch(_:)`; on `.single`, reply with `application/json`; on `.stream`,
/// reply with `text/event-stream` and write each chunk as it arrives (chunks
/// are already SSE-framed).
public struct JSONRPCDispatcher: Sendable {
    /// The result of dispatching one request body.
    public enum Outcome: Sendable {
        /// A complete JSON-RPC response body (`application/json`).
        case single(Data)
        /// SSE-framed JSON-RPC response events (`text/event-stream`).
        case stream(AsyncThrowingStream<Data, Error>)
    }

    private let handler: any A2ARequestHandler

    public init(handler: any A2ARequestHandler) {
        self.handler = handler
    }

    /// Decodes a JSON-RPC request, invokes the handler, and encodes the response.
    ///
    /// Never throws: malformed input, unknown methods, and handler errors are
    /// all returned as JSON-RPC error responses per the spec §5.4 code table.
    public func dispatch(_ body: Data) async -> Outcome {
        let envelope: RawRequest
        do {
            envelope = try A2AJSON.decoder().decode(RawRequest.self, from: body)
        } catch {
            return .single(encodeError(id: .null, A2AError(.parseError)))
        }
        let id = envelope.id ?? .null
        guard envelope.jsonrpc == "2.0", let method = envelope.method else {
            return .single(encodeError(id: id, A2AError(.invalidRequest)))
        }
        do {
            switch method {
            case A2AMethod.sendMessage:
                return .single(
                    try encodeResult(id: id, try await handler.sendMessage(decodeParams(envelope.params))))
            case A2AMethod.sendStreamingMessage:
                return .stream(
                    frame(try await handler.sendStreamingMessage(decodeParams(envelope.params)), id: id))
            case A2AMethod.getTask:
                return .single(
                    try encodeResult(id: id, try await handler.getTask(decodeParams(envelope.params))))
            case A2AMethod.listTasks:
                return .single(
                    try encodeResult(id: id, try await handler.listTasks(decodeParams(envelope.params))))
            case A2AMethod.cancelTask:
                return .single(
                    try encodeResult(id: id, try await handler.cancelTask(decodeParams(envelope.params))))
            case A2AMethod.subscribeToTask:
                return .stream(
                    frame(try await handler.subscribeToTask(decodeParams(envelope.params)), id: id))
            case A2AMethod.createTaskPushNotificationConfig:
                return .single(
                    try encodeResult(
                        id: id,
                        try await handler.createTaskPushNotificationConfig(
                            decodeParams(envelope.params))))
            case A2AMethod.getTaskPushNotificationConfig:
                return .single(
                    try encodeResult(
                        id: id,
                        try await handler.getTaskPushNotificationConfig(decodeParams(envelope.params))))
            case A2AMethod.listTaskPushNotificationConfigs:
                return .single(
                    try encodeResult(
                        id: id,
                        try await handler.listTaskPushNotificationConfigs(decodeParams(envelope.params))))
            case A2AMethod.deleteTaskPushNotificationConfig:
                try await handler.deleteTaskPushNotificationConfig(decodeParams(envelope.params))
                return .single(try encodeResult(id: id, JSONValue.object([:])))
            case A2AMethod.getExtendedAgentCard:
                return .single(
                    try encodeResult(
                        id: id, try await handler.getExtendedAgentCard(decodeParams(envelope.params))))
            default:
                return .single(encodeError(id: id, A2AError(.methodNotFound)))
            }
        } catch {
            return .single(encodeError(id: id, error))
        }
    }

    /// Wraps a JSON payload as one SSE event: `data: {payload}\n\n`.
    public static func sseFrame(_ payload: Data) -> Data {
        var framed = Data("data: ".utf8)
        framed.append(payload)
        framed.append(Data("\n\n".utf8))
        return framed
    }

    // MARK: - Internals

    private struct RawRequest: Decodable {
        var jsonrpc: String?
        var id: JSONRPCID?
        var method: String?
        var params: JSONValue?
    }

    private func decodeParams<Params: Decodable>(_ params: JSONValue?) throws -> Params {
        do {
            let data = try A2AJSON.encoder().encode(params ?? .object([:]))
            return try A2AJSON.decoder().decode(Params.self, from: data)
        } catch {
            throw A2AError(.invalidParams, message: "Invalid parameters: \(error)")
        }
    }

    private func encodeResult<Result: Codable & Sendable>(
        id: JSONRPCID, _ result: Result
    ) throws -> Data {
        try A2AJSON.encoder().encode(JSONRPCResponse(id: id, result: result))
    }

    private func encodeError(id: JSONRPCID, _ error: any Error) -> Data {
        let a2aError =
            error as? A2AError
            ?? A2AError(.internalError, message: "Internal error: \(error)")
        let response = JSONRPCResponse<JSONValue>(
            id: id, result: nil, error: a2aError.errorObject)
        if let data = try? A2AJSON.encoder().encode(response) {
            return data
        }
        // Unreachable in practice; a syntactically valid fallback keeps this non-throwing.
        return Data(
            #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"#.utf8)
    }

    private func frame(
        _ stream: AsyncThrowingStream<StreamResponse, Error>, id: JSONRPCID
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in stream {
                        let payload = try A2AJSON.encoder().encode(
                            JSONRPCResponse(id: id, result: event))
                        continuation.yield(Self.sseFrame(payload))
                    }
                } catch {
                    continuation.yield(Self.sseFrame(encodeError(id: id, error)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
