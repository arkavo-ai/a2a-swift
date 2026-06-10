# Hummingbird adapter example

`a2a-swift`'s server core is deliberately HTTP-framework-agnostic: `JSONRPCDispatcher` is `Data` in → `Data` out (or a stream of SSE-framed `Data` for streaming methods). This example shows the complete glue needed to serve it over [Hummingbird](https://github.com/hummingbird-project/hummingbird) — about 30 lines in [`Adapter.swift`](Sources/EchoTaskAgent/Adapter.swift):

- `GET /.well-known/agent-card.json` serves the agent card
- `POST /` hands the body to `JSONRPCDispatcher.dispatch(_:)` and maps the outcome to `application/json` or `text/event-stream`

The same shape works for Vapor or raw NIO — only the route registration and response-body types change.

## Run

```sh
swift run EchoTaskAgent     # listens on 127.0.0.1:8081
```

Smoke test:

```sh
curl http://127.0.0.1:8081/.well-known/agent-card.json
curl -X POST http://127.0.0.1:8081/ \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"SendMessage","params":{"message":{"messageId":"m1","role":"ROLE_USER","parts":[{"text":"hi"}]}}}'
```

`EchoTaskAgent` opens a task for every message, echoes the text back as an artifact, and supports `SendStreamingMessage` (SSE), `GetTask`, `ListTasks`, and `CancelTask` semantics.

This example is a standalone package (so the core SDK keeps zero dependencies) and is not built by the root package's CI.
