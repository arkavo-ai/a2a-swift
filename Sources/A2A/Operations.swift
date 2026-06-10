import Foundation

/// Authentication details used for push notifications (`lf.a2a.v1.AuthenticationInfo`).
public struct AuthenticationInfo: Sendable, Codable, Equatable {
    /// HTTP authentication scheme from the IANA registry, e.g. `Bearer`, `Basic`.
    public var scheme: String
    /// Push notification credentials. Format depends on the scheme (e.g. token for Bearer).
    public var credentials: String?

    public init(scheme: String, credentials: String? = nil) {
        self.scheme = scheme
        self.credentials = credentials
    }
}

/// Associates a push notification configuration with a task (`lf.a2a.v1.TaskPushNotificationConfig`).
public struct TaskPushNotificationConfig: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// A unique identifier (e.g. UUID) for this push notification configuration.
    public var id: String?
    /// The ID of the task this configuration is associated with.
    public var taskId: String?
    /// The URL where the notification should be sent.
    public var url: String
    /// A token unique for this task or session.
    public var token: String?
    /// Authentication information required to send the notification.
    public var authentication: AuthenticationInfo?

    public init(
        tenant: String? = nil,
        id: String? = nil,
        taskId: String? = nil,
        url: String,
        token: String? = nil,
        authentication: AuthenticationInfo? = nil
    ) {
        self.tenant = tenant
        self.id = id
        self.taskId = taskId
        self.url = url
        self.token = token
        self.authentication = authentication
    }
}

/// Configuration of a send message request (`lf.a2a.v1.SendMessageConfiguration`).
public struct SendMessageConfiguration: Sendable, Codable, Equatable {
    /// Media types the client is prepared to accept for response parts.
    public var acceptedOutputModes: [String]
    /// Configuration for the agent to send push notifications for task updates.
    /// The task id should be empty when sent in a `SendMessage` request.
    public var taskPushNotificationConfig: TaskPushNotificationConfig?
    /// The maximum number of most recent messages from the task's history to
    /// retrieve in the response. Unset means no limit; zero requests none.
    public var historyLength: Int32?
    /// If true, the operation returns immediately after creating the task. If
    /// false (default), the operation waits for a terminal or interrupted state.
    public var returnImmediately: Bool

    public init(
        acceptedOutputModes: [String] = [],
        taskPushNotificationConfig: TaskPushNotificationConfig? = nil,
        historyLength: Int32? = nil,
        returnImmediately: Bool = false
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.taskPushNotificationConfig = taskPushNotificationConfig
        self.historyLength = historyLength
        self.returnImmediately = returnImmediately
    }

    private enum CodingKeys: String, CodingKey {
        case acceptedOutputModes, taskPushNotificationConfig, historyLength, returnImmediately
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acceptedOutputModes =
            try container.decodeIfPresent([String].self, forKey: .acceptedOutputModes) ?? []
        taskPushNotificationConfig = try container.decodeIfPresent(
            TaskPushNotificationConfig.self, forKey: .taskPushNotificationConfig)
        historyLength = try container.decodeIfPresent(Int32.self, forKey: .historyLength)
        returnImmediately = try container.decodeIfPresent(Bool.self, forKey: .returnImmediately) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !acceptedOutputModes.isEmpty {
            try container.encode(acceptedOutputModes, forKey: .acceptedOutputModes)
        }
        try container.encodeIfPresent(taskPushNotificationConfig, forKey: .taskPushNotificationConfig)
        try container.encodeIfPresent(historyLength, forKey: .historyLength)
        if returnImmediately {
            try container.encode(returnImmediately, forKey: .returnImmediately)
        }
    }
}

// MARK: - Requests

/// Request for the `SendMessage` and `SendStreamingMessage` methods (`lf.a2a.v1.SendMessageRequest`).
public struct SendMessageRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The message to send to the agent.
    public var message: Message
    /// Configuration for the send request.
    public var configuration: SendMessageConfiguration?
    /// A flexible key-value map for passing additional context or parameters.
    public var metadata: [String: JSONValue]?

    public init(
        tenant: String? = nil,
        message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.tenant = tenant
        self.message = message
        self.configuration = configuration
        self.metadata = metadata
    }
}

/// Request for the `GetTask` method (`lf.a2a.v1.GetTaskRequest`).
public struct GetTaskRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The resource ID of the task to retrieve.
    public var id: String
    /// The maximum number of most recent messages from the task's history to retrieve.
    public var historyLength: Int32?

    public init(tenant: String? = nil, id: String, historyLength: Int32? = nil) {
        self.tenant = tenant
        self.id = id
        self.historyLength = historyLength
    }
}

/// Request for the `ListTasks` method (`lf.a2a.v1.ListTasksRequest`).
public struct ListTasksRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// Filter tasks by context ID.
    public var contextId: String?
    /// Filter tasks by their current status state.
    public var status: TaskState?
    /// The maximum number of tasks to return (1...100; default 50).
    public var pageSize: Int32?
    /// A page token received from a previous `ListTasks` call.
    public var pageToken: String?
    /// The maximum number of messages to include in each task's history.
    public var historyLength: Int32?
    /// Only return tasks whose status timestamp is at or after this ISO 8601 timestamp.
    public var statusTimestampAfter: String?
    /// Whether to include artifacts in the returned tasks. Defaults to false.
    public var includeArtifacts: Bool?

    public init(
        tenant: String? = nil,
        contextId: String? = nil,
        status: TaskState? = nil,
        pageSize: Int32? = nil,
        pageToken: String? = nil,
        historyLength: Int32? = nil,
        statusTimestampAfter: String? = nil,
        includeArtifacts: Bool? = nil
    ) {
        self.tenant = tenant
        self.contextId = contextId
        self.status = status
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.historyLength = historyLength
        self.statusTimestampAfter = statusTimestampAfter
        self.includeArtifacts = includeArtifacts
    }
}

/// Request for the `CancelTask` method (`lf.a2a.v1.CancelTaskRequest`).
public struct CancelTaskRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The resource ID of the task to cancel.
    public var id: String
    /// A flexible key-value map for passing additional context or parameters.
    public var metadata: [String: JSONValue]?

    public init(tenant: String? = nil, id: String, metadata: [String: JSONValue]? = nil) {
        self.tenant = tenant
        self.id = id
        self.metadata = metadata
    }
}

/// Request for the `SubscribeToTask` method (`lf.a2a.v1.SubscribeToTaskRequest`).
public struct SubscribeToTaskRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The resource ID of the task to subscribe to.
    public var id: String

    public init(tenant: String? = nil, id: String) {
        self.tenant = tenant
        self.id = id
    }
}

/// Request for the `GetTaskPushNotificationConfig` method
/// (`lf.a2a.v1.GetTaskPushNotificationConfigRequest`).
public struct GetTaskPushNotificationConfigRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The parent task resource ID.
    public var taskId: String
    /// The resource ID of the configuration to retrieve.
    public var id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }
}

/// Request for the `DeleteTaskPushNotificationConfig` method
/// (`lf.a2a.v1.DeleteTaskPushNotificationConfigRequest`).
public struct DeleteTaskPushNotificationConfigRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The parent task resource ID.
    public var taskId: String
    /// The resource ID of the configuration to delete.
    public var id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }
}

/// Request for the `ListTaskPushNotificationConfigs` method
/// (`lf.a2a.v1.ListTaskPushNotificationConfigsRequest`).
public struct ListTaskPushNotificationConfigsRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?
    /// The parent task resource ID.
    public var taskId: String
    /// The maximum number of configurations to return.
    public var pageSize: Int32?
    /// A page token received from a previous call.
    public var pageToken: String?

    public init(
        tenant: String? = nil,
        taskId: String,
        pageSize: Int32? = nil,
        pageToken: String? = nil
    ) {
        self.tenant = tenant
        self.taskId = taskId
        self.pageSize = pageSize
        self.pageToken = pageToken
    }
}

/// Request for the `GetExtendedAgentCard` method (`lf.a2a.v1.GetExtendedAgentCardRequest`).
public struct GetExtendedAgentCardRequest: Sendable, Codable, Equatable {
    /// Opaque routing identifier; must match the `tenant` from the selected `AgentInterface` when set.
    public var tenant: String?

    public init(tenant: String? = nil) {
        self.tenant = tenant
    }
}

// MARK: - Responses

/// Response for the `ListTasks` method (`lf.a2a.v1.ListTasksResponse`).
public struct ListTasksResponse: Sendable, Codable, Equatable {
    /// Tasks matching the specified criteria.
    public var tasks: [A2ATask]
    /// A token to retrieve the next page of results, or empty if there are no more.
    public var nextPageToken: String?
    /// The page size used for this response.
    public var pageSize: Int32
    /// Total number of tasks available (before pagination).
    public var totalSize: Int32

    public init(
        tasks: [A2ATask],
        nextPageToken: String? = nil,
        pageSize: Int32,
        totalSize: Int32
    ) {
        self.tasks = tasks
        self.nextPageToken = nextPageToken
        self.pageSize = pageSize
        self.totalSize = totalSize
    }

    private enum CodingKeys: String, CodingKey {
        case tasks, nextPageToken, pageSize, totalSize
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([A2ATask].self, forKey: .tasks) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        pageSize = try container.decodeIfPresent(Int32.self, forKey: .pageSize) ?? 0
        totalSize = try container.decodeIfPresent(Int32.self, forKey: .totalSize) ?? 0
    }
}

/// Response for the `ListTaskPushNotificationConfigs` method
/// (`lf.a2a.v1.ListTaskPushNotificationConfigsResponse`).
public struct ListTaskPushNotificationConfigsResponse: Sendable, Codable, Equatable {
    /// The list of push notification configurations.
    public var configs: [TaskPushNotificationConfig]
    /// A token to retrieve the next page of results, or empty if there are no more.
    public var nextPageToken: String?

    public init(configs: [TaskPushNotificationConfig], nextPageToken: String? = nil) {
        self.configs = configs
        self.nextPageToken = nextPageToken
    }

    private enum CodingKeys: String, CodingKey {
        case configs, nextPageToken
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configs =
            try container.decodeIfPresent([TaskPushNotificationConfig].self, forKey: .configs) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

/// Response for the `SendMessage` method (`lf.a2a.v1.SendMessageResponse`).
///
/// A oneof: in JSON, exactly one of `task` or `message` is present.
public enum SendMessageResponse: Sendable, Codable, Equatable {
    /// The task created or updated by the message.
    case task(A2ATask)
    /// A message from the agent.
    case message(Message)

    private enum CodingKeys: String, CodingKey {
        case task, message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let task = try container.decodeIfPresent(A2ATask.self, forKey: .task) {
            self = .task(task)
        } else if let message = try container.decodeIfPresent(Message.self, forKey: .message) {
            self = .message(message)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "SendMessageResponse must contain one of: task, message"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        }
    }
}

/// A streamed event from `SendStreamingMessage` or `SubscribeToTask` (`lf.a2a.v1.StreamResponse`).
///
/// A oneof: in JSON, exactly one of `task`, `message`, `statusUpdate`, or
/// `artifactUpdate` is present.
public enum StreamResponse: Sendable, Codable, Equatable {
    /// A task object containing the current state of the task.
    case task(A2ATask)
    /// A message from the agent.
    case message(Message)
    /// An event indicating a task status update.
    case statusUpdate(TaskStatusUpdateEvent)
    /// An event indicating a task artifact update.
    case artifactUpdate(TaskArtifactUpdateEvent)

    private enum CodingKeys: String, CodingKey {
        case task, message, statusUpdate, artifactUpdate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let task = try container.decodeIfPresent(A2ATask.self, forKey: .task) {
            self = .task(task)
        } else if let message = try container.decodeIfPresent(Message.self, forKey: .message) {
            self = .message(message)
        } else if let update = try container.decodeIfPresent(
            TaskStatusUpdateEvent.self, forKey: .statusUpdate)
        {
            self = .statusUpdate(update)
        } else if let update = try container.decodeIfPresent(
            TaskArtifactUpdateEvent.self, forKey: .artifactUpdate)
        {
            self = .artifactUpdate(update)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription:
                        "StreamResponse must contain one of: task, message, statusUpdate, artifactUpdate"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        case .statusUpdate(let update):
            try container.encode(update, forKey: .statusUpdate)
        case .artifactUpdate(let update):
            try container.encode(update, forKey: .artifactUpdate)
        }
    }
}
