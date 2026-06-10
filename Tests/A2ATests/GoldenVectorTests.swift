import Foundation
import Testing

@testable import A2A

func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite("Golden vectors from the A2A specification")
struct GoldenVectorTests {
    @Test func agentCardDecodesAndRoundTrips() throws {
        let decoder = A2AJSON.decoder()
        let card = try decoder.decode(AgentCard.self, from: try fixture("agent-card"))

        #expect(card.name == "GeoSpatial Route Planner Agent")
        #expect(card.version == "1.2.0")
        #expect(card.supportedInterfaces.count == 3)
        #expect(card.supportedInterfaces[0].protocolBinding == AgentInterface.Binding.jsonrpc)
        #expect(card.supportedInterfaces[0].protocolVersion == "1.0")
        #expect(card.provider?.organization == "Example Geo Services Inc.")
        #expect(card.capabilities.streaming == true)
        #expect(card.capabilities.extendedAgentCard == true)
        #expect(card.capabilities.extensions.count == 1)
        #expect(card.capabilities.extensions[0].required == false)
        #expect(card.skills.count == 2)
        #expect(card.skills[0].tags.contains("traffic"))
        #expect(card.signatures.count == 1)
        #expect(card.iconUrl == "https://georoute-agent.example.com/icon.png")

        guard case .openIdConnect(let oidc)? = card.securitySchemes?["google"] else {
            Issue.record("expected openIdConnect scheme for 'google'")
            return
        }
        #expect(
            oidc.openIdConnectUrl == "https://accounts.google.com/.well-known/openid-configuration")
        guard case .apiKey(let apiKey)? = card.securitySchemes?["apiKey"] else {
            Issue.record("expected apiKey scheme for 'apiKey'")
            return
        }
        #expect(apiKey.location == "header")
        #expect(apiKey.name == "X-API-Key")
        #expect(card.securityRequirements.count == 1)
        #expect(
            card.securityRequirements[0].schemes["google"]?.list == ["openid", "profile", "email"])

        let reencoded = try A2AJSON.encoder().encode(card)
        let redecoded = try decoder.decode(AgentCard.self, from: reencoded)
        #expect(redecoded == card)
    }

    @Test func taskDecodesAndRoundTrips() throws {
        let decoder = A2AJSON.decoder()
        let task = try decoder.decode(A2ATask.self, from: try fixture("task"))

        #expect(task.id == "3f36680c-7f37-4a5f-945e-d78981fafd36")
        #expect(task.status.state == .completed)
        #expect(task.status.state.isTerminal)
        #expect(task.status.timestamp == "2024-03-15T10:15:00.123Z")
        #expect(task.status.message?.role == .agent)
        #expect(task.artifacts.count == 1)
        #expect(task.artifacts[0].parts.count == 4)
        #expect(task.history.count == 1)
        #expect(task.history[0].extensions == ["https://example.com/extensions/geolocation/v1"])
        #expect(task.history[0].referenceTaskIds == ["earlier-task-uuid"])
        #expect(task.metadata?["priority"] == .string("high"))

        let parts = task.artifacts[0].parts
        guard case .text(let text) = parts[0].content else {
            Issue.record("expected text part")
            return
        }
        #expect(text.hasPrefix("Today will be sunny"))
        guard case .raw(let bytes) = parts[1].content else {
            Issue.record("expected raw part")
            return
        }
        #expect(String(decoding: bytes, as: UTF8.self) == "hello world")
        guard case .url(let url) = parts[2].content else {
            Issue.record("expected url part")
            return
        }
        #expect(url == "https://example.com/report.pdf")
        guard case .data(let data) = parts[3].content else {
            Issue.record("expected data part")
            return
        }
        #expect(data["high"] == .number(75))
        #expect(data["sunny"] == .bool(true))

        let geo = task.history[0].metadata?["https://example.com/extensions/geolocation/v1"]
        #expect(geo?["latitude"] == .number(37.7749))

        let reencoded = try A2AJSON.encoder().encode(task)
        let redecoded = try decoder.decode(A2ATask.self, from: reencoded)
        #expect(redecoded == task)
    }

    @Test func sendMessageResponseEnvelopeDecodes() throws {
        let response = try A2AJSON.decoder().decode(
            JSONRPCResponse<SendMessageResponse>.self,
            from: try fixture("send-message-response"))

        #expect(response.jsonrpc == "2.0")
        #expect(response.id == .number(1))
        #expect(response.error == nil)
        guard case .task(let task)? = response.result else {
            Issue.record("expected task payload")
            return
        }
        #expect(task.id == "task-uuid")
        #expect(task.status.state == .completed)
        #expect(task.artifacts[0].name == "Weather Report")
    }

    @Test func errorResponseDecodes() throws {
        let response = try A2AJSON.decoder().decode(
            JSONRPCResponse<JSONValue>.self,
            from: try fixture("error-task-not-found"))

        #expect(response.id == .number(2))
        #expect(response.result == nil)
        let errorObject = try #require(response.error)
        #expect(errorObject.code == A2AErrorCode.taskNotFound.rawValue)
        #expect(errorObject.message == "Task not found")

        let error = A2AError(errorObject)
        #expect(error.errorCode == .taskNotFound)
        let detail = try #require(error.data?[0])
        #expect(detail["@type"] == .string("type.googleapis.com/google.rpc.ErrorInfo"))
        #expect(detail["reason"] == .string("TASK_NOT_FOUND"))
    }

    @Test func unknownFieldsAreIgnored() throws {
        // Spec §5.7: implementations SHOULD ignore unrecognized fields.
        let json = Data(
            #"{"id":"t","status":{"state":"TASK_STATE_WORKING"},"futureField":{"x":1}}"#.utf8)
        let task = try A2AJSON.decoder().decode(A2ATask.self, from: json)
        #expect(task.status.state == .working)
    }
}
