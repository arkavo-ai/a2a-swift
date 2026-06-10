import A2A
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Errors raised by `A2AClient` outside of protocol-level `A2AError`s.
public enum A2AClientError: Error, Sendable {
    /// The interface URL is not a valid URL.
    case invalidURL(String)
    /// The JSON-RPC response contained neither a result nor an error.
    case missingResult
}

/// Request types that carry the optional `tenant` routing field.
protocol TenantScoped {
    var tenant: String? { get set }
}

extension SendMessageRequest: TenantScoped {}
extension GetTaskRequest: TenantScoped {}
extension ListTasksRequest: TenantScoped {}
extension CancelTaskRequest: TenantScoped {}
extension SubscribeToTaskRequest: TenantScoped {}
extension TaskPushNotificationConfig: TenantScoped {}
extension GetTaskPushNotificationConfigRequest: TenantScoped {}
extension DeleteTaskPushNotificationConfigRequest: TenantScoped {}
extension ListTaskPushNotificationConfigsRequest: TenantScoped {}
extension GetExtendedAgentCardRequest: TenantScoped {}

/// A JSON-RPC client for the A2A protocol.
///
/// Talks to a single `AgentInterface` with the `JSONRPC` protocol binding.
/// When the interface declares a `tenant`, it is echoed automatically on every
/// request that does not already set one (spec requirement).
public struct A2AClient: Sendable {
    /// The interface this client talks to.
    public let interface: AgentInterface
    /// Extension URIs to activate, sent in the `A2A-Extensions` header.
    public var activatedExtensions: [String]

    private let transport: any A2ATransport
    private let authenticator: (any RequestAuthenticator)?

    public init(
        interface: AgentInterface,
        transport: any A2ATransport = URLSessionTransport(),
        authenticator: (any RequestAuthenticator)? = nil,
        activatedExtensions: [String] = []
    ) {
        self.interface = interface
        self.transport = transport
        self.authenticator = authenticator
        self.activatedExtensions = activatedExtensions
    }

    /// Creates a client for an agent card, selecting the preferred JSONRPC interface.
    ///
    /// Throws `AgentCardResolverError.noCompatibleInterface` if the card
    /// declares no compatible JSONRPC interface.
    public init(
        card: AgentCard,
        transport: any A2ATransport = URLSessionTransport(),
        authenticator: (any RequestAuthenticator)? = nil,
        activatedExtensions: [String] = []
    ) throws {
        guard let interface = AgentCardResolver.selectInterface(from: card) else {
            throw AgentCardResolverError.noCompatibleInterface
        }
        self.init(
            interface: interface,
            transport: transport,
            authenticator: authenticator,
            activatedExtensions: activatedExtensions
        )
    }

    // MARK: - Operations

    /// Sends a message to the agent (`SendMessage`).
    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await call(method: A2AMethod.sendMessage, params: withTenant(request))
    }

    /// Sends a message and streams responses in real time (`SendStreamingMessage`).
    public func sendStreamingMessage(
        _ request: SendMessageRequest
    ) -> AsyncThrowingStream<StreamResponse, Error> {
        streamCall(method: A2AMethod.sendStreamingMessage, params: withTenant(request))
    }

    /// Gets the latest state of a task (`GetTask`).
    public func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await call(method: A2AMethod.getTask, params: withTenant(request))
    }

    /// Lists tasks matching the given filter (`ListTasks`).
    public func listTasks(_ request: ListTasksRequest = ListTasksRequest()) async throws
        -> ListTasksResponse
    {
        try await call(method: A2AMethod.listTasks, params: withTenant(request))
    }

    /// Cancels a task in progress (`CancelTask`).
    public func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await call(method: A2AMethod.cancelTask, params: withTenant(request))
    }

    /// Subscribes to updates for a task not in a terminal state (`SubscribeToTask`).
    public func subscribeToTask(
        _ request: SubscribeToTaskRequest
    ) -> AsyncThrowingStream<StreamResponse, Error> {
        streamCall(method: A2AMethod.subscribeToTask, params: withTenant(request))
    }

    /// Creates a push notification config for a task (`CreateTaskPushNotificationConfig`).
    public func createTaskPushNotificationConfig(
        _ config: TaskPushNotificationConfig
    ) async throws -> TaskPushNotificationConfig {
        try await call(
            method: A2AMethod.createTaskPushNotificationConfig, params: withTenant(config))
    }

    /// Gets a push notification config for a task (`GetTaskPushNotificationConfig`).
    public func getTaskPushNotificationConfig(
        _ request: GetTaskPushNotificationConfigRequest
    ) async throws -> TaskPushNotificationConfig {
        try await call(method: A2AMethod.getTaskPushNotificationConfig, params: withTenant(request))
    }

    /// Lists push notification configs for a task (`ListTaskPushNotificationConfigs`).
    public func listTaskPushNotificationConfigs(
        _ request: ListTaskPushNotificationConfigsRequest
    ) async throws -> ListTaskPushNotificationConfigsResponse {
        try await call(
            method: A2AMethod.listTaskPushNotificationConfigs, params: withTenant(request))
    }

    /// Deletes a push notification config for a task (`DeleteTaskPushNotificationConfig`).
    public func deleteTaskPushNotificationConfig(
        _ request: DeleteTaskPushNotificationConfigRequest
    ) async throws {
        // The result is google.protobuf.Empty; decode and discard whatever JSON it is.
        let _: JSONValue = try await call(
            method: A2AMethod.deleteTaskPushNotificationConfig, params: withTenant(request))
    }

    /// Gets the extended agent card for the authenticated agent (`GetExtendedAgentCard`).
    public func getExtendedAgentCard(
        _ request: GetExtendedAgentCardRequest = GetExtendedAgentCardRequest()
    ) async throws -> AgentCard {
        try await call(method: A2AMethod.getExtendedAgentCard, params: withTenant(request))
    }

    // MARK: - Internals

    private func withTenant<R: TenantScoped>(_ request: R) -> R {
        guard request.tenant == nil, let tenant = interface.tenant else {
            return request
        }
        var scoped = request
        scoped.tenant = tenant
        return scoped
    }

    private func makeRequest(accept: String) async throws -> URLRequest {
        guard let url = URL(string: interface.url) else {
            throw A2AClientError.invalidURL(interface.url)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(A2AProtocol.version, forHTTPHeaderField: A2AHTTPHeader.version)
        if !activatedExtensions.isEmpty {
            request.setValue(
                activatedExtensions.joined(separator: ", "),
                forHTTPHeaderField: A2AHTTPHeader.extensions)
        }
        if let authenticator {
            try await authenticator.authenticate(&request)
        }
        return request
    }

    private func call<Params: Codable & Sendable, Result: Codable & Sendable>(
        method: String, params: Params
    ) async throws -> Result {
        var request = try await makeRequest(accept: "application/json")
        request.httpBody = try A2AJSON.encoder().encode(
            JSONRPCRequest(id: .string(UUID().uuidString), method: method, params: params))
        let (data, statusCode) = try await transport.post(request)
        guard (200..<300).contains(statusCode) else {
            throw A2ATransportError.httpError(statusCode: statusCode, body: data)
        }
        let response = try A2AJSON.decoder().decode(JSONRPCResponse<Result>.self, from: data)
        if let error = response.error {
            throw A2AError(error)
        }
        guard let result = response.result else {
            throw A2AClientError.missingResult
        }
        return result
    }

    private func streamCall<Params: Codable & Sendable>(
        method: String, params: Params
    ) -> AsyncThrowingStream<StreamResponse, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = try await makeRequest(accept: "text/event-stream")
                    request.httpBody = try A2AJSON.encoder().encode(
                        JSONRPCRequest(
                            id: .string(UUID().uuidString), method: method, params: params))
                    var parser = SSEParser()
                    for try await chunk in transport.stream(request) {
                        for event in parser.feed(chunk) {
                            let response = try A2AJSON.decoder().decode(
                                JSONRPCResponse<StreamResponse>.self, from: Data(event.data.utf8))
                            if let error = response.error {
                                throw A2AError(error)
                            }
                            if let result = response.result {
                                continuation.yield(result)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
