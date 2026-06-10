import Foundation
import Testing

@testable import A2A

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let data = try A2AJSON.encoder().encode(value)
    return try A2AJSON.decoder().decode(T.self, from: data)
}

private func encodeToObject<T: Encodable>(_ value: T) throws -> [String: JSONValue] {
    let data = try A2AJSON.encoder().encode(value)
    let json = try A2AJSON.decoder().decode(JSONValue.self, from: data)
    return json.objectValue ?? [:]
}

@Suite("Part oneof coding")
struct PartCodingTests {
    @Test func textPart() throws {
        let part = Part.text("hello", mediaType: "text/plain")
        let object = try encodeToObject(part)
        #expect(object["text"] == .string("hello"))
        #expect(object["mediaType"] == .string("text/plain"))
        #expect(try roundTrip(part) == part)
    }

    @Test func rawPartUsesBase64() throws {
        let part = Part.raw(Data("hello world".utf8), filename: "hello.bin")
        let object = try encodeToObject(part)
        #expect(object["raw"] == .string("aGVsbG8gd29ybGQ="))
        #expect(object["filename"] == .string("hello.bin"))
        #expect(try roundTrip(part) == part)
    }

    @Test func urlPart() throws {
        let part = Part.url("https://example.com/a.png", mediaType: "image/png")
        #expect(try roundTrip(part) == part)
    }

    @Test func dataPart() throws {
        let part = Part.data(["values": [1, 2, 3], "nested": ["ok": true]])
        #expect(try roundTrip(part) == part)
    }

    @Test func dataPartAcceptsNonObjectValues() throws {
        // google.protobuf.Value permits any JSON value, not just objects.
        for value in [JSONValue.string("s"), .number(4), .bool(false), .array([1, "two"]), .null] {
            let part = Part.data(value)
            #expect(try roundTrip(part) == part)
        }
    }

    @Test func invalidBase64Throws() {
        let json = Data(#"{"raw":"not-base64!!!"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try A2AJSON.decoder().decode(Part.self, from: json)
        }
    }

    @Test func missingContentThrows() {
        let json = Data(#"{"mediaType":"text/plain"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try A2AJSON.decoder().decode(Part.self, from: json)
        }
    }
}

@Suite("Response oneof coding")
struct ResponseOneofTests {
    private let task = A2ATask(id: "t1", status: TaskStatus(state: .working))
    private let message = Message(messageId: "m1", role: .agent, parts: [.text("hi")])

    @Test func sendMessageResponseVariants() throws {
        let taskResponse = SendMessageResponse.task(task)
        #expect(try encodeToObject(taskResponse).keys.sorted() == ["task"])
        #expect(try roundTrip(taskResponse) == taskResponse)

        let messageResponse = SendMessageResponse.message(message)
        #expect(try encodeToObject(messageResponse).keys.sorted() == ["message"])
        #expect(try roundTrip(messageResponse) == messageResponse)
    }

    @Test func streamResponseVariants() throws {
        let variants: [(StreamResponse, String)] = [
            (.task(task), "task"),
            (.message(message), "message"),
            (
                .statusUpdate(
                    TaskStatusUpdateEvent(
                        taskId: "t1", contextId: "c1", status: TaskStatus(state: .completed))),
                "statusUpdate"
            ),
            (
                .artifactUpdate(
                    TaskArtifactUpdateEvent(
                        taskId: "t1", contextId: "c1",
                        artifact: Artifact(artifactId: "a1", parts: [.text("chunk")]),
                        append: true, lastChunk: true)),
                "artifactUpdate"
            ),
        ]
        for (variant, expectedKey) in variants {
            #expect(try encodeToObject(variant).keys.sorted() == [expectedKey])
            #expect(try roundTrip(variant) == variant)
        }
    }

    @Test func emptyStreamResponseThrows() {
        #expect(throws: DecodingError.self) {
            try A2AJSON.decoder().decode(StreamResponse.self, from: Data("{}".utf8))
        }
    }
}

@Suite("SecurityScheme oneof coding")
struct SecuritySchemeTests {
    @Test func allFiveVariantsRoundTrip() throws {
        let schemes: [(SecurityScheme, String)] = [
            (
                .apiKey(APIKeySecurityScheme(location: "header", name: "X-API-Key")),
                "apiKeySecurityScheme"
            ),
            (
                .httpAuth(HTTPAuthSecurityScheme(scheme: "Bearer", bearerFormat: "JWT")),
                "httpAuthSecurityScheme"
            ),
            (
                .oauth2(
                    OAuth2SecurityScheme(
                        flows: .clientCredentials(
                            ClientCredentialsOAuthFlow(
                                tokenUrl: "https://auth.example.com/token",
                                scopes: ["read": "Read access"])),
                        oauth2MetadataUrl: "https://auth.example.com/.well-known/oauth")),
                "oauth2SecurityScheme"
            ),
            (
                .openIdConnect(
                    OpenIdConnectSecurityScheme(
                        openIdConnectUrl: "https://example.com/.well-known/openid-configuration")),
                "openIdConnectSecurityScheme"
            ),
            (.mtls(MutualTLSSecurityScheme(description: "Client certs")), "mtlsSecurityScheme"),
        ]
        for (scheme, expectedKey) in schemes {
            #expect(try encodeToObject(scheme).keys.sorted() == [expectedKey])
            #expect(try roundTrip(scheme) == scheme)
        }
    }

    @Test func oauthFlowVariantsRoundTrip() throws {
        let flows: [OAuthFlows] = [
            .authorizationCode(
                AuthorizationCodeOAuthFlow(
                    authorizationUrl: "https://auth.example.com/authorize",
                    tokenUrl: "https://auth.example.com/token",
                    scopes: ["openid": "OpenID"],
                    pkceRequired: true)),
            .clientCredentials(
                ClientCredentialsOAuthFlow(
                    tokenUrl: "https://auth.example.com/token", scopes: [:])),
            .implicit(ImplicitOAuthFlow(authorizationUrl: "https://auth.example.com/authorize")),
            .password(PasswordOAuthFlow(tokenUrl: "https://auth.example.com/token")),
            .deviceCode(
                DeviceCodeOAuthFlow(
                    deviceAuthorizationUrl: "https://auth.example.com/device",
                    tokenUrl: "https://auth.example.com/token",
                    scopes: ["offline": "Offline access"])),
        ]
        for flow in flows {
            #expect(try roundTrip(flow) == flow)
        }
    }

    @Test func emptySecuritySchemeThrows() {
        #expect(throws: DecodingError.self) {
            try A2AJSON.decoder().decode(SecurityScheme.self, from: Data("{}".utf8))
        }
    }
}

@Suite("JSONValue coding")
struct JSONValueTests {
    @Test func roundTripsNestedStructure() throws {
        let value: JSONValue = [
            "string": "text",
            "number": 42.5,
            "bool": true,
            "null": nil,
            "array": [1, "two", false, nil],
            "object": ["nested": ["deep": true]],
        ]
        #expect(try roundTrip(value) == value)
    }

    @Test func accessors() {
        let value: JSONValue = ["items": [10, 20], "name": "x"]
        #expect(value["items"]?[1] == .number(20))
        #expect(value["name"]?.stringValue == "x")
        #expect(value["missing"] == nil)
        #expect(value["items"]?[5] == nil)
    }
}
