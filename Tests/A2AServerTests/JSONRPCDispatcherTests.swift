import A2A
import Foundation
import Testing

@testable import A2AServer

/// A minimal in-memory handler covering the dispatcher tests.
struct StubHandler: A2ARequestHandler {
    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        .task(
            A2ATask(
                id: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .completed),
                history: [request.message]))
    }

    func sendStreamingMessage(
        _ request: SendMessageRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.task(A2ATask(id: "task-1", status: TaskStatus(state: .working))))
            continuation.yield(
                .statusUpdate(
                    TaskStatusUpdateEvent(
                        taskId: "task-1", contextId: "ctx-1",
                        status: TaskStatus(state: .completed))))
            continuation.finish()
        }
    }

    func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        guard request.id == "task-1" else {
            throw A2AError(.taskNotFound)
        }
        return A2ATask(id: request.id, status: TaskStatus(state: .working))
    }

    func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        ListTasksResponse(tasks: [], pageSize: 50, totalSize: 0)
    }

    func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        throw A2AError(.taskNotCancelable)
    }

    func subscribeToTask(
        _ request: SubscribeToTaskRequest
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        throw A2AError(.unsupportedOperation)
    }

    func deleteTaskPushNotificationConfig(
        _ request: DeleteTaskPushNotificationConfigRequest
    ) async throws {
        // Accept silently; exercised by the delete test.
    }
}

private func dispatchSingle(_ body: String) async throws -> JSONValue {
    let dispatcher = JSONRPCDispatcher(handler: StubHandler())
    let outcome = await dispatcher.dispatch(Data(body.utf8))
    guard case .single(let data) = outcome else {
        throw A2AError(.internalError, message: "expected single outcome")
    }
    return try A2AJSON.decoder().decode(JSONValue.self, from: data)
}

@Suite("JSONRPCDispatcher")
struct JSONRPCDispatcherTests {
    @Test func sendMessageReturnsResult() async throws {
        let response = try await dispatchSingle(
            #"""
            {"jsonrpc":"2.0","id":1,"method":"SendMessage","params":{"message":{"messageId":"m1","role":"ROLE_USER","parts":[{"text":"hi"}]}}}
            """#)
        #expect(response["jsonrpc"] == .string("2.0"))
        #expect(response["id"] == .number(1))
        #expect(response["error"] == nil)
        #expect(response["result"]?["task"]?["id"] == .string("task-1"))
        #expect(
            response["result"]?["task"]?["status"]?["state"] == .string("TASK_STATE_COMPLETED"))
    }

    @Test func malformedJSONReturnsParseError() async throws {
        let response = try await dispatchSingle("{not json")
        #expect(response["id"] == .null)
        #expect(response["error"]?["code"] == .number(-32700))
    }

    @Test func missingJSONRPCVersionReturnsInvalidRequest() async throws {
        let response = try await dispatchSingle(#"{"id":1,"method":"GetTask","params":{}}"#)
        #expect(response["error"]?["code"] == .number(-32600))
        #expect(response["id"] == .number(1))
    }

    @Test func unknownMethodReturnsMethodNotFound() async throws {
        let response = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":"r1","method":"NoSuchMethod","params":{}}"#)
        #expect(response["error"]?["code"] == .number(-32601))
        #expect(response["id"] == .string("r1"))
    }

    @Test func invalidParamsReturnsInvalidParams() async throws {
        // GetTask requires an id parameter.
        let response = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":5,"method":"GetTask","params":{}}"#)
        #expect(response["error"]?["code"] == .number(-32602))
    }

    @Test func handlerA2AErrorIsMapped() async throws {
        let response = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":6,"method":"GetTask","params":{"id":"missing"}}"#)
        #expect(response["error"]?["code"] == .number(-32001))
        #expect(response["error"]?["message"] == .string("Task not found"))
    }

    @Test func cancelTaskMapsNotCancelable() async throws {
        let response = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":7,"method":"CancelTask","params":{"id":"task-1"}}"#)
        #expect(response["error"]?["code"] == .number(-32002))
    }

    @Test func defaultHandlerImplementationsMapErrors() async throws {
        // StubHandler relies on protocol defaults for push-config get/list and
        // extended card.
        let pushResponse = try await dispatchSingle(
            #"""
            {"jsonrpc":"2.0","id":8,"method":"GetTaskPushNotificationConfig","params":{"taskId":"t","id":"c"}}
            """#)
        #expect(pushResponse["error"]?["code"] == .number(-32003))

        let cardResponse = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":9,"method":"GetExtendedAgentCard","params":{}}"#)
        #expect(cardResponse["error"]?["code"] == .number(-32007))
    }

    @Test func getExtendedAgentCardToleratesMissingParams() async throws {
        // Spec example §9.4.8 sends no params member at all.
        let response = try await dispatchSingle(
            #"{"jsonrpc":"2.0","id":10,"method":"GetExtendedAgentCard"}"#)
        #expect(response["error"]?["code"] == .number(-32007))
    }

    @Test func deleteReturnsEmptyResult() async throws {
        let response = try await dispatchSingle(
            #"""
            {"jsonrpc":"2.0","id":11,"method":"DeleteTaskPushNotificationConfig","params":{"taskId":"t","id":"c"}}
            """#)
        #expect(response["error"] == nil)
        #expect(response["result"] == .object([:]))
    }

    @Test func streamingMethodReturnsSSEFrames() async throws {
        let dispatcher = JSONRPCDispatcher(handler: StubHandler())
        let body = #"""
            {"jsonrpc":"2.0","id":"s1","method":"SendStreamingMessage","params":{"message":{"messageId":"m1","role":"ROLE_USER","parts":[{"text":"go"}]}}}
            """#
        let outcome = await dispatcher.dispatch(Data(body.utf8))
        guard case .stream(let stream) = outcome else {
            Issue.record("expected stream outcome")
            return
        }

        var frames: [Data] = []
        for try await frame in stream {
            frames.append(frame)
        }
        #expect(frames.count == 2)

        for frame in frames {
            let text = String(decoding: frame, as: UTF8.self)
            #expect(text.hasPrefix("data: "))
            #expect(text.hasSuffix("\n\n"))
        }

        let payloads = try frames.map { frame in
            let text = String(decoding: frame, as: UTF8.self)
            let json = String(text.dropFirst("data: ".count).dropLast(2))
            return try A2AJSON.decoder().decode(
                JSONRPCResponse<StreamResponse>.self, from: Data(json.utf8))
        }
        #expect(payloads.allSatisfy { $0.id == .string("s1") })
        guard case .task(let task)? = payloads[0].result else {
            Issue.record("expected task event")
            return
        }
        #expect(task.status.state == .working)
        guard case .statusUpdate(let update)? = payloads[1].result else {
            Issue.record("expected statusUpdate event")
            return
        }
        #expect(update.status.state == .completed)
    }

    @Test func streamingHandlerErrorReturnsSingleError() async throws {
        let dispatcher = JSONRPCDispatcher(handler: StubHandler())
        let outcome = await dispatcher.dispatch(
            Data(#"{"jsonrpc":"2.0","id":12,"method":"SubscribeToTask","params":{"id":"t"}}"#.utf8))
        guard case .single(let data) = outcome else {
            Issue.record("expected single error outcome")
            return
        }
        let response = try A2AJSON.decoder().decode(JSONValue.self, from: data)
        #expect(response["error"]?["code"] == .number(-32004))
    }

    @Test func sseFrameFormat() {
        let frame = JSONRPCDispatcher.sseFrame(Data(#"{"a":1}"#.utf8))
        #expect(String(decoding: frame, as: UTF8.self) == "data: {\"a\":1}\n\n")
    }
}
