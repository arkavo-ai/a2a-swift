// The generic a2a-swift <-> Hummingbird glue. This is the entire adapter:
// one route for the agent card, one route handing the request body to
// `JSONRPCDispatcher` and translating its outcome into an HTTP response
// (plain JSON, or SSE for streaming methods).

import A2A
import A2AServer
import Foundation
import Hummingbird

func addA2ARoutes(
    to router: Router<some RequestContext>,
    card: AgentCard,
    handler: some A2ARequestHandler,
    rpcPath: String = "/"
) throws {
    let dispatcher = JSONRPCDispatcher(handler: handler)
    let encodedCard = try A2AJSON.encoder().encode(card)

    router.get(RouterPath(A2AProtocol.agentCardWellKnownPath)) { _, _ in
        Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: ResponseBody(byteBuffer: ByteBuffer(bytes: encodedCard))
        )
    }

    router.post(RouterPath(rpcPath)) { request, _ in
        let body = try await request.body.collect(upTo: 4 << 20)
        switch await dispatcher.dispatch(Data(body.readableBytesView)) {
        case .single(let data):
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: data))
            )
        case .stream(let events):
            return Response(
                status: .ok,
                headers: [.contentType: "text/event-stream"],
                body: ResponseBody(asyncSequence: events.map { ByteBuffer(bytes: $0) })
            )
        }
    }
}
