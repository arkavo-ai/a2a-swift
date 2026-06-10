import Foundation
import Testing

@testable import A2A

@Suite("TaskState")
struct TaskStateTests {
    @Test func protoNameSerialization() throws {
        let data = try A2AJSON.encoder().encode([TaskState.inputRequired, .completed])
        #expect(
            String(decoding: data, as: UTF8.self)
                == #"["TASK_STATE_INPUT_REQUIRED","TASK_STATE_COMPLETED"]"#)
    }

    @Test func terminalStates() {
        #expect(TaskState.allCases.filter(\.isTerminal) == [.completed, .failed, .canceled, .rejected])
    }

    @Test func interruptedStates() {
        #expect(TaskState.allCases.filter(\.isInterrupted) == [.inputRequired, .authRequired])
    }

    @Test func roleSerialization() throws {
        let data = try A2AJSON.encoder().encode([Role.user, .agent])
        #expect(String(decoding: data, as: UTF8.self) == #"["ROLE_USER","ROLE_AGENT"]"#)
    }
}

@Suite("Error codes")
struct ErrorCodeTests {
    @Test func codesMatchSpecTable() {
        // Spec §5.4 / §9.5.
        #expect(A2AErrorCode.parseError.rawValue == -32700)
        #expect(A2AErrorCode.invalidRequest.rawValue == -32600)
        #expect(A2AErrorCode.methodNotFound.rawValue == -32601)
        #expect(A2AErrorCode.invalidParams.rawValue == -32602)
        #expect(A2AErrorCode.internalError.rawValue == -32603)
        #expect(A2AErrorCode.taskNotFound.rawValue == -32001)
        #expect(A2AErrorCode.taskNotCancelable.rawValue == -32002)
        #expect(A2AErrorCode.pushNotificationNotSupported.rawValue == -32003)
        #expect(A2AErrorCode.unsupportedOperation.rawValue == -32004)
        #expect(A2AErrorCode.contentTypeNotSupported.rawValue == -32005)
        #expect(A2AErrorCode.invalidAgentResponse.rawValue == -32006)
        #expect(A2AErrorCode.extendedAgentCardNotConfigured.rawValue == -32007)
        #expect(A2AErrorCode.extensionSupportRequired.rawValue == -32008)
        #expect(A2AErrorCode.versionNotSupported.rawValue == -32009)
    }

    @Test func unknownCodesArePreserved() {
        let error = A2AError(code: -31999, message: "vendor error")
        #expect(error.errorCode == nil)
        #expect(error.errorObject.code == -31999)
    }
}

@Suite("JSON-RPC envelope")
struct JSONRPCTests {
    @Test func methodNamesArePascalCase() {
        // Spec §5.3: JSON-RPC method names are identical to gRPC method names.
        #expect(A2AMethod.all.count == 11)
        #expect(A2AMethod.sendMessage == "SendMessage")
        #expect(A2AMethod.sendStreamingMessage == "SendStreamingMessage")
        #expect(A2AMethod.createTaskPushNotificationConfig == "CreateTaskPushNotificationConfig")
        #expect(A2AMethod.streaming.contains(A2AMethod.subscribeToTask))
        #expect(!A2AMethod.streaming.contains(A2AMethod.sendMessage))
    }

    @Test func requestEncodesEnvelope() throws {
        let request = JSONRPCRequest(
            id: .string("req-1"),
            method: A2AMethod.getTask,
            params: GetTaskRequest(id: "task-1", historyLength: 10))
        let data = try A2AJSON.encoder().encode(request)
        let json = try A2AJSON.decoder().decode(JSONValue.self, from: data)
        #expect(json["jsonrpc"] == .string("2.0"))
        #expect(json["id"] == .string("req-1"))
        #expect(json["method"] == .string("GetTask"))
        #expect(json["params"]?["id"] == .string("task-1"))
        #expect(json["params"]?["historyLength"] == .number(10))
    }

    @Test func idVariantsRoundTrip() throws {
        for raw in [#""abc""#, "42", "null"] {
            let id = try A2AJSON.decoder().decode(JSONRPCID.self, from: Data(raw.utf8))
            let reencoded = try A2AJSON.encoder().encode(id)
            #expect(String(decoding: reencoded, as: UTF8.self) == raw)
        }
        #expect(try A2AJSON.decoder().decode(JSONRPCID.self, from: Data("42".utf8)) == .number(42))
    }

    @Test func serviceParameterHeaderNames() {
        // Spec §9.2: service parameters travel as HTTP headers.
        #expect(A2AHTTPHeader.version == "A2A-Version")
        #expect(A2AHTTPHeader.extensions == "A2A-Extensions")
        #expect(A2AProtocol.version == "1.0")
        #expect(A2AProtocol.agentCardWellKnownPath == "/.well-known/agent-card.json")
    }

    @Test func tenantFieldPresentOnAllRequestTypes() throws {
        // Spec §8.3.2 rule 4: every request message carries the tenant from
        // the selected interface. Verify the field encodes on each type.
        let requests: [any Encodable] = [
            SendMessageRequest(
                tenant: "t", message: Message(messageId: "m", role: .user, parts: [.text("x")])),
            GetTaskRequest(tenant: "t", id: "1"),
            ListTasksRequest(tenant: "t"),
            CancelTaskRequest(tenant: "t", id: "1"),
            SubscribeToTaskRequest(tenant: "t", id: "1"),
            TaskPushNotificationConfig(tenant: "t", url: "https://example.com/hook"),
            GetTaskPushNotificationConfigRequest(tenant: "t", taskId: "1", id: "2"),
            DeleteTaskPushNotificationConfigRequest(tenant: "t", taskId: "1", id: "2"),
            ListTaskPushNotificationConfigsRequest(tenant: "t", taskId: "1"),
            GetExtendedAgentCardRequest(tenant: "t"),
        ]
        for request in requests {
            let data = try A2AJSON.encoder().encode(request)
            let json = try A2AJSON.decoder().decode(JSONValue.self, from: data)
            #expect(json["tenant"] == .string("t"), "tenant missing on \(type(of: request))")
        }
    }
}
