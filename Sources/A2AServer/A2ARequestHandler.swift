import A2A

/// The application-side implementation of the A2A operations.
///
/// Implement this protocol and hand it to `JSONRPCDispatcher` to serve A2A
/// over any HTTP server (Vapor, Hummingbird, etc. — this package has no HTTP
/// server dependency). Throw `A2AError` to return a protocol error with the
/// proper JSON-RPC code (spec §5.4); any other thrown error is mapped to
/// `internalError` (-32603).
public protocol A2ARequestHandler: Sendable {
    /// Handles `SendMessage`.
    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse

    /// Handles `SendStreamingMessage`. Events are delivered to the client as
    /// Server-Sent Events, each wrapping one `StreamResponse`.
    func sendStreamingMessage(
        _ request: SendMessageRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Handles `GetTask`.
    func getTask(_ request: GetTaskRequest) async throws -> A2ATask

    /// Handles `ListTasks`.
    func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse

    /// Handles `CancelTask`.
    func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask

    /// Handles `SubscribeToTask`. Must throw `A2AError(.unsupportedOperation)`
    /// if the task is already in a terminal state.
    func subscribeToTask(
        _ request: SubscribeToTaskRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Handles `CreateTaskPushNotificationConfig`.
    func createTaskPushNotificationConfig(
        _ config: TaskPushNotificationConfig
    ) async throws -> TaskPushNotificationConfig

    /// Handles `GetTaskPushNotificationConfig`.
    func getTaskPushNotificationConfig(
        _ request: GetTaskPushNotificationConfigRequest
    ) async throws -> TaskPushNotificationConfig

    /// Handles `ListTaskPushNotificationConfigs`.
    func listTaskPushNotificationConfigs(
        _ request: ListTaskPushNotificationConfigsRequest
    ) async throws -> ListTaskPushNotificationConfigsResponse

    /// Handles `DeleteTaskPushNotificationConfig`.
    func deleteTaskPushNotificationConfig(
        _ request: DeleteTaskPushNotificationConfigRequest
    ) async throws

    /// Handles `GetExtendedAgentCard`.
    func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard
}

extension A2ARequestHandler {
    /// Default: push notifications are not supported.
    public func createTaskPushNotificationConfig(
        _ config: TaskPushNotificationConfig
    ) async throws -> TaskPushNotificationConfig {
        throw A2AError(.pushNotificationNotSupported)
    }

    /// Default: push notifications are not supported.
    public func getTaskPushNotificationConfig(
        _ request: GetTaskPushNotificationConfigRequest
    ) async throws -> TaskPushNotificationConfig {
        throw A2AError(.pushNotificationNotSupported)
    }

    /// Default: push notifications are not supported.
    public func listTaskPushNotificationConfigs(
        _ request: ListTaskPushNotificationConfigsRequest
    ) async throws -> ListTaskPushNotificationConfigsResponse {
        throw A2AError(.pushNotificationNotSupported)
    }

    /// Default: push notifications are not supported.
    public func deleteTaskPushNotificationConfig(
        _ request: DeleteTaskPushNotificationConfigRequest
    ) async throws {
        throw A2AError(.pushNotificationNotSupported)
    }

    /// Default: no extended agent card is configured.
    public func getExtendedAgentCard(
        _ request: GetExtendedAgentCardRequest
    ) async throws -> AgentCard {
        throw A2AError(.extendedAgentCardNotConfigured)
    }
}
