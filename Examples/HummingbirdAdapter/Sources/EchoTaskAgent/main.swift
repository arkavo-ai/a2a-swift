// EchoTaskAgent — an A2A agent that opens a task for every message, echoes
// the text back as an artifact, and supports streaming, task retrieval,
// listing, and cancellation semantics. Serves a2a-swift's A2AServer over
// Hummingbird via the adapter in Adapter.swift.
//
//     swift run EchoTaskAgent          # listens on 127.0.0.1:8081

import A2A
import A2AServer
import Foundation
import Hummingbird

actor TaskStore {
    private var tasks: [String: A2ATask] = [:]

    func save(_ task: A2ATask) { tasks[task.id] = task }

    func get(_ id: String) -> A2ATask? { tasks[id] }

    func all() -> [A2ATask] { Array(tasks.values) }
}

struct EchoTaskHandler: A2ARequestHandler {
    let store: TaskStore

    private func echoText(from message: Message) -> String {
        let text = message.parts.compactMap { part -> String? in
            if case .text(let text) = part.content { return text }
            return nil
        }.joined(separator: " ")
        return "echo: \(text)"
    }

    private func makeTask(for request: SendMessageRequest, state: TaskState) -> A2ATask {
        A2ATask(
            id: UUID().uuidString,
            contextId: request.message.contextId ?? UUID().uuidString,
            status: TaskStatus(
                state: state,
                timestamp: ISO8601DateFormatter().string(from: Date())),
            artifacts: [
                Artifact(
                    artifactId: UUID().uuidString,
                    name: "echo",
                    parts: [.text(echoText(from: request.message), mediaType: "text/plain")])
            ],
            history: [request.message])
    }

    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        let task = makeTask(for: request, state: .completed)
        await store.save(task)
        return .task(task)
    }

    func sendStreamingMessage(
        _ request: SendMessageRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let task = makeTask(for: request, state: .working)
        let completed = A2ATask(
            id: task.id, contextId: task.contextId,
            status: TaskStatus(state: .completed), artifacts: task.artifacts,
            history: task.history)
        await store.save(completed)
        return AsyncThrowingStream { continuation in
            continuation.yield(.task(task))
            continuation.yield(
                .artifactUpdate(
                    TaskArtifactUpdateEvent(
                        taskId: task.id, contextId: task.contextId ?? "",
                        artifact: task.artifacts[0], lastChunk: true)))
            continuation.yield(
                .statusUpdate(
                    TaskStatusUpdateEvent(
                        taskId: task.id, contextId: task.contextId ?? "",
                        status: TaskStatus(state: .completed))))
            continuation.finish()
        }
    }

    func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        guard let task = await store.get(request.id) else {
            throw A2AError(.taskNotFound)
        }
        return task
    }

    func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        let tasks = await store.all()
        return ListTasksResponse(
            tasks: tasks, pageSize: Int32(tasks.count), totalSize: Int32(tasks.count))
    }

    func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        guard let task = await store.get(request.id) else {
            throw A2AError(.taskNotFound)
        }
        guard !task.status.state.isTerminal else {
            throw A2AError(.taskNotCancelable)
        }
        var canceled = task
        canceled.status = TaskStatus(state: .canceled)
        await store.save(canceled)
        return canceled
    }

    func subscribeToTask(
        _ request: SubscribeToTaskRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        throw A2AError(.unsupportedOperation)
    }
}

let host = ProcessInfo.processInfo.environment["A2A_HOST"] ?? "127.0.0.1"
let port = ProcessInfo.processInfo.environment["A2A_PORT"].flatMap(Int.init) ?? 8081

let card = AgentCard(
    name: "EchoTaskAgent",
    description: "a2a-swift example agent: echoes messages back as task artifacts.",
    supportedInterfaces: [
        AgentInterface(
            url: "http://\(host):\(port)/",
            protocolBinding: AgentInterface.Binding.jsonrpc,
            protocolVersion: "1.0")
    ],
    version: "0.1.0",
    capabilities: AgentCapabilities(streaming: true),
    defaultInputModes: ["text/plain"],
    defaultOutputModes: ["text/plain"],
    skills: [
        AgentSkill(
            id: "echo", name: "Echo",
            description: "Echoes the user's message back as a task artifact.",
            tags: ["demo", "echo"])
    ])

let router = Router()
try addA2ARoutes(to: router, card: card, handler: EchoTaskHandler(store: TaskStore()))

let app = Application(
    router: router,
    configuration: .init(address: .hostname(host, port: port)))
print("EchoTaskAgent listening on http://\(host):\(port)")
try await app.runService()
