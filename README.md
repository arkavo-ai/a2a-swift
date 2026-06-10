# a2a-swift

Swift SDK for the [Agent2Agent (A2A) Protocol](https://a2a-protocol.org).

A2A is an open protocol enabling communication and interoperability between opaque agentic applications. This package implements the A2A **v1.0** data model, JSON-RPC protocol binding, client, and server-side dispatcher in pure Swift with zero third-party dependencies.

## Supported platforms

| Platform | Minimum |
| :--- | :--- |
| macOS | 14 |
| iOS / iPadOS | 17 |
| tvOS | 17 |
| watchOS | 10 |
| visionOS | 1 |
| Linux | Swift 6.1+ |

Built with `swift-tools-version: 6.1` and the Swift 6 language mode (strict concurrency). CI verifies macOS and Linux (`swift:6.3`).

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arkavo-ai/a2a-swift.git", from: "0.1.0")
]
```

Then depend on the products you need:

```swift
.target(name: "MyAgentApp", dependencies: [
    .product(name: "A2AClient", package: "a2a-swift"),  // client + data model
    .product(name: "A2AServer", package: "a2a-swift"),  // server-side dispatcher
])
```

| Product | Contents |
| :--- | :--- |
| `A2A` | Data model and JSON-RPC envelope types. No networking. |
| `A2AClient` | Agent card resolution, JSON-RPC client, SSE streaming. Foundation URLSession only. |
| `A2AServer` | `A2ARequestHandler` protocol and `JSONRPCDispatcher`. No HTTP server dependency. |

## Quickstart: client

```swift
import A2A
import A2AClient

// 1. Resolve the agent card from its well-known URI.
let resolver = AgentCardResolver()
let card = try await resolver.resolve(domain: "agent.example.com")

// 2. Create a client for the card's preferred JSONRPC interface.
let client = try A2AClient(card: card)

// 3. Send a message.
let response = try await client.sendMessage(
    SendMessageRequest(
        message: Message(
            messageId: UUID().uuidString,
            role: .user,
            parts: [.text("What is the weather today?")])))

switch response {
case .task(let task):
    print("Task \(task.id) is \(task.status.state)")
case .message(let message):
    print("Agent replied: \(message.parts)")
}
```

### Streaming

```swift
for try await event in client.sendStreamingMessage(request) {
    switch event {
    case .task(let task):              print("task: \(task.status.state)")
    case .message(let message):        print("message: \(message.messageId)")
    case .statusUpdate(let update):    print("status: \(update.status.state)")
    case .artifactUpdate(let update):  print("artifact: \(update.artifact.artifactId)")
    }
}
```

### Authentication

Authentication is pluggable via `RequestAuthenticator`, which mutates each outgoing `URLRequest`:

```swift
struct BearerAuthenticator: RequestAuthenticator {
    let token: String
    func authenticate(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

let client = try A2AClient(card: card, authenticator: BearerAuthenticator(token: token))
```

The card's `securitySchemes` field describes which schemes the agent accepts (API key, HTTP auth, OAuth 2.0, OpenID Connect, mTLS).

## Quickstart: server

Implement `A2ARequestHandler` and wire `JSONRPCDispatcher` into any HTTP framework. The dispatcher is `Data` in, `Data` out — this package does not depend on an HTTP server.

```swift
import A2A
import A2AServer

struct MyAgent: A2ARequestHandler {
    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        .task(A2ATask(
            id: UUID().uuidString,
            contextId: request.message.contextId ?? UUID().uuidString,
            status: TaskStatus(state: .completed),
            artifacts: [Artifact(artifactId: UUID().uuidString, parts: [.text("Hello!")])]))
    }
    // ... remaining operations; push-notification and extended-card
    // operations have default implementations that return the proper
    // "not supported" protocol errors.
}
```

Example Vapor adapter:

```swift
let dispatcher = JSONRPCDispatcher(handler: MyAgent())

app.post("a2a", "v1") { req async throws -> Response in
    let body = Data(buffer: req.body.data ?? ByteBuffer())
    switch await dispatcher.dispatch(body) {
    case .single(let data):
        return Response(status: .ok,
                        headers: ["Content-Type": "application/json"],
                        body: .init(data: data))
    case .stream(let events):
        let response = Response(status: .ok,
                                headers: ["Content-Type": "text/event-stream"])
        response.body = .init(asyncStream: { writer in
            for try await chunk in events {   // chunks are already SSE-framed
                try await writer.write(.buffer(ByteBuffer(data: chunk)))
            }
            try await writer.write(.end)
        })
        return response
    }
}
```

Errors thrown from your handler as `A2AError` are mapped to the spec §5.4 JSON-RPC code table; anything else becomes `-32603 Internal error`.

## Specification conformance

This SDK tracks **A2A v1.0.1** (`a2aproject/A2A`, `specification/a2a.proto`) and follows the proto3 JSON mapping mandated by the spec:

- **camelCase field names** (`contextId`, `protocolVersion`, …)
- **Proto-name enum strings** (`"TASK_STATE_COMPLETED"`, `"ROLE_USER"`)
- **Oneofs as exactly-one-key objects** (`Part` content, `SendMessageResponse`, `StreamResponse`, `SecurityScheme`, `OAuthFlows`)
- **`bytes` as base64 strings** (`Part` raw content)
- **Timestamps as ISO 8601 strings**, kept as `String` to round-trip fractional precision losslessly
- **PascalCase JSON-RPC method names** identical to the gRPC service (`SendMessage`, `GetTask`, …)
- **Service parameters as HTTP headers** (`A2A-Version`, `A2A-Extensions`)
- **`tenant` echoing**: the client automatically copies the selected interface's `tenant` into every request

The proto `Task` message is named `A2ATask` in Swift to avoid colliding with `Swift.Task`; the wire format is unchanged.

Protocol extensions attach via the spec's `AgentExtension` mechanism, the `A2A-Extensions` header (`A2AClient.activatedExtensions`), `RequestAuthenticator`, and custom `A2ATransport` implementations — core types never need patching.

## License

[Apache 2.0](LICENSE)
