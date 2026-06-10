import A2A
import Foundation
import Testing

@testable import A2AClient

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Captures requests and replays canned responses. Test-only; the lock keeps
/// the shared state Sendable.
final class MockTransport: A2ATransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []

    var responseBody = Data()
    var responseStatus = 200
    var streamChunks: [Data] = []

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    var lastRequestJSON: JSONValue? {
        guard let body = requests.last?.httpBody else { return nil }
        return try? A2AJSON.decoder().decode(JSONValue.self, from: body)
    }

    private func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
    }

    func post(_ request: URLRequest) async throws -> (Data, Int) {
        record(request)
        return (responseBody, responseStatus)
    }

    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        record(request)
        let chunks = streamChunks
        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }

    func respond(result: String, id: String = "any") {
        responseBody = Data(
            #"{"jsonrpc":"2.0","id":"\#(id)","result":\#(result)}"#.utf8)
    }
}

private let testInterface = AgentInterface(
    url: "https://agent.example.com/a2a/v1",
    protocolBinding: AgentInterface.Binding.jsonrpc,
    tenant: "tenant-1",
    protocolVersion: "1.0")

private let workingTask = #"{"id":"task-1","status":{"state":"TASK_STATE_WORKING"}}"#

@Suite("A2AClient")
struct A2AClientTests {
    @Test func sendMessageEncodesEnvelopeAndHeaders() async throws {
        let transport = MockTransport()
        transport.respond(result: #"{"task":\#(workingTask)}"#)
        let client = A2AClient(
            interface: testInterface, transport: transport,
            activatedExtensions: ["https://ext.example.com/v1"])

        let response = try await client.sendMessage(
            SendMessageRequest(message: Message(messageId: "m1", role: .user, parts: [.text("hi")])))

        guard case .task(let task) = response else {
            Issue.record("expected task response")
            return
        }
        #expect(task.id == "task-1")
        #expect(task.status.state == .working)

        let request = try #require(transport.requests.last)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == testInterface.url)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: A2AHTTPHeader.version) == "1.0")
        #expect(
            request.value(forHTTPHeaderField: A2AHTTPHeader.extensions)
                == "https://ext.example.com/v1")

        let json = try #require(transport.lastRequestJSON)
        #expect(json["jsonrpc"] == .string("2.0"))
        #expect(json["method"] == .string("SendMessage"))
        #expect(json["id"] != nil)
        #expect(json["params"]?["message"]?["messageId"] == .string("m1"))
    }

    @Test func tenantIsEchoedFromInterface() async throws {
        let transport = MockTransport()
        transport.respond(result: workingTask)
        let client = A2AClient(interface: testInterface, transport: transport)

        _ = try await client.getTask(GetTaskRequest(id: "task-1"))

        let json = try #require(transport.lastRequestJSON)
        #expect(json["params"]?["tenant"] == .string("tenant-1"))
    }

    @Test func explicitTenantIsNotOverridden() async throws {
        let transport = MockTransport()
        transport.respond(result: workingTask)
        let client = A2AClient(interface: testInterface, transport: transport)

        _ = try await client.getTask(GetTaskRequest(tenant: "other", id: "task-1"))

        let json = try #require(transport.lastRequestJSON)
        #expect(json["params"]?["tenant"] == .string("other"))
    }

    @Test func errorResponseThrowsA2AError() async throws {
        let transport = MockTransport()
        transport.responseBody = Data(
            #"{"jsonrpc":"2.0","id":"1","error":{"code":-32001,"message":"Task not found"}}"#.utf8)
        let client = A2AClient(interface: testInterface, transport: transport)

        await #expect(throws: A2AError(.taskNotFound)) {
            _ = try await client.getTask(GetTaskRequest(id: "missing"))
        }
    }

    @Test func httpErrorThrows() async throws {
        let transport = MockTransport()
        transport.responseStatus = 503
        let client = A2AClient(interface: testInterface, transport: transport)

        await #expect(throws: A2ATransportError.self) {
            _ = try await client.getTask(GetTaskRequest(id: "task-1"))
        }
    }

    @Test func streamingDecodesSSEEvents() async throws {
        let transport = MockTransport()
        let frames = [
            #"data: {"jsonrpc":"2.0","id":"1","result":{"task":\#(workingTask)}}"#,
            "",
            #"data: {"jsonrpc":"2.0","id":"1","result":{"statusUpdate":{"taskId":"task-1","contextId":"c1","status":{"state":"TASK_STATE_COMPLETED"}}}}"#,
            "",
            "",
        ].joined(separator: "\n")
        // Deliver in tiny chunks to exercise incremental parsing.
        transport.streamChunks = Array(frames.utf8).chunks(of: 7).map { Data($0) }
        let client = A2AClient(interface: testInterface, transport: transport)

        var events: [StreamResponse] = []
        for try await event in client.sendStreamingMessage(
            SendMessageRequest(message: Message(messageId: "m1", role: .user, parts: [.text("go")])))
        {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .task(let task) = events[0] else {
            Issue.record("expected task event first")
            return
        }
        #expect(task.status.state == .working)
        guard case .statusUpdate(let update) = events[1] else {
            Issue.record("expected statusUpdate event second")
            return
        }
        #expect(update.status.state == .completed)

        let request = try #require(transport.requests.last)
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        let json = try #require(transport.lastRequestJSON)
        #expect(json["method"] == .string("SendStreamingMessage"))
    }

    @Test func streamingErrorEventThrows() async throws {
        let transport = MockTransport()
        transport.streamChunks = [
            Data(
                #"data: {"jsonrpc":"2.0","id":"1","error":{"code":-32004,"message":"This operation is not supported"}}\#n\#n"#
                    .utf8)
        ]
        let client = A2AClient(interface: testInterface, transport: transport)

        await #expect(throws: A2AError(.unsupportedOperation)) {
            for try await _ in client.subscribeToTask(SubscribeToTaskRequest(id: "task-1")) {}
        }
    }

    @Test func deletePushConfigToleratesEmptyResult() async throws {
        let transport = MockTransport()
        transport.respond(result: "{}")
        let client = A2AClient(interface: testInterface, transport: transport)

        try await client.deleteTaskPushNotificationConfig(
            DeleteTaskPushNotificationConfigRequest(taskId: "task-1", id: "cfg-1"))

        let json = try #require(transport.lastRequestJSON)
        #expect(json["method"] == .string("DeleteTaskPushNotificationConfig"))
    }

    @Test func authenticatorMutatesRequest() async throws {
        struct BearerAuthenticator: RequestAuthenticator {
            func authenticate(_ request: inout URLRequest) async throws {
                request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
            }
        }
        let transport = MockTransport()
        transport.respond(result: workingTask)
        let client = A2AClient(
            interface: testInterface, transport: transport, authenticator: BearerAuthenticator())

        _ = try await client.getTask(GetTaskRequest(id: "task-1"))

        let request = try #require(transport.requests.last)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func initFromCardSelectsJSONRPCInterface() throws {
        let card = AgentCard(
            name: "Test", description: "Test agent",
            supportedInterfaces: [
                AgentInterface(
                    url: "https://grpc.example.com", protocolBinding: "GRPC", protocolVersion: "1.0"),
                testInterface,
            ],
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text/plain"], defaultOutputModes: ["text/plain"], skills: [])
        let client = try A2AClient(card: card, transport: MockTransport())
        #expect(client.interface == testInterface)
    }

    @Test func incompatibleCardThrows() {
        let card = AgentCard(
            name: "Test", description: "Test agent",
            supportedInterfaces: [
                AgentInterface(
                    url: "https://old.example.com", protocolBinding: "JSONRPC",
                    protocolVersion: "0.3")
            ],
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text/plain"], defaultOutputModes: ["text/plain"], skills: [])
        #expect(throws: AgentCardResolverError.self) {
            _ = try A2AClient(card: card, transport: MockTransport())
        }
    }
}

@Suite("AgentCardResolver")
struct AgentCardResolverTests {
    @Test func resolvesFromWellKnownURL() async throws {
        let card = AgentCard(
            name: "Test", description: "Test agent",
            supportedInterfaces: [testInterface],
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text/plain"], defaultOutputModes: ["text/plain"], skills: [])
        let transport = MockTransport()
        transport.responseBody = try A2AJSON.encoder().encode(card)
        let resolver = AgentCardResolver(transport: transport)

        let resolved = try await resolver.resolve(domain: "agent.example.com")

        #expect(resolved == card)
        let request = try #require(transport.requests.last)
        #expect(
            request.url?.absoluteString
                == "https://agent.example.com/.well-known/agent-card.json")
        #expect(request.httpMethod == "GET")
    }

    @Test func interfaceWithoutProtocolVersionIsAccepted() throws {
        // The reference SDKs omit protocolVersion (proto3 default omission);
        // such interfaces decode with an empty version and remain selectable.
        let json = Data(
            #"""
            {"name":"HW","description":"d","version":"0.0.1",
             "capabilities":{"streaming":true},
             "supportedInterfaces":[{"url":"http://127.0.0.1:9999","protocolBinding":"JSONRPC"}],
             "defaultInputModes":["text/plain"],"defaultOutputModes":["text/plain"],"skills":[]}
            """#.utf8)
        let card = try A2AJSON.decoder().decode(AgentCard.self, from: json)
        let interface = try #require(AgentCardResolver.selectInterface(from: card))
        #expect(interface.url == "http://127.0.0.1:9999")
        #expect(interface.protocolVersion.isEmpty)
    }

    @Test func selectInterfaceFiltersBindingAndVersion() {
        let grpc = AgentInterface(
            url: "https://grpc.example.com", protocolBinding: "GRPC", protocolVersion: "1.0")
        let oldJSONRPC = AgentInterface(
            url: "https://old.example.com", protocolBinding: "JSONRPC", protocolVersion: "0.3")
        let card = AgentCard(
            name: "Test", description: "Test agent",
            supportedInterfaces: [grpc, oldJSONRPC, testInterface],
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text/plain"], defaultOutputModes: ["text/plain"], skills: [])

        #expect(AgentCardResolver.selectInterface(from: card) == testInterface)
        #expect(AgentCardResolver.selectInterface(from: card, binding: "GRPC") == grpc)
        #expect(AgentCardResolver.selectInterface(from: card, binding: "HTTP+JSON") == nil)
    }
}

extension Array {
    fileprivate func chunks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
