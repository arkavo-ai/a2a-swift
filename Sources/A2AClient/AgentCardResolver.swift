import A2A
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Errors raised while resolving an agent card.
public enum AgentCardResolverError: Error, Sendable {
    /// The domain could not be combined into a valid well-known URL.
    case invalidDomain(String)
    /// No interface in the card matched the requested binding and protocol version.
    case noCompatibleInterface
}

/// Fetches and decodes agent cards from their well-known location (spec §8.6).
public struct AgentCardResolver: Sendable {
    private let transport: any A2ATransport

    public init(transport: any A2ATransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// Resolves the agent card at `https://{domain}/.well-known/agent-card.json`.
    public func resolve(domain: String) async throws -> AgentCard {
        guard let url = URL(string: "https://\(domain)\(A2AProtocol.agentCardWellKnownPath)") else {
            throw AgentCardResolverError.invalidDomain(domain)
        }
        return try await resolve(url: url)
    }

    /// Resolves an agent card from an explicit URL.
    public func resolve(url: URL) async throws -> AgentCard {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, statusCode) = try await transport.post(request)
        guard (200..<300).contains(statusCode) else {
            throw A2ATransportError.httpError(statusCode: statusCode, body: data)
        }
        return try A2AJSON.decoder().decode(AgentCard.self, from: data)
    }

    /// Selects the preferred interface from a card.
    ///
    /// Interfaces are ordered by preference (spec: the first entry is
    /// preferred), so this returns the first interface matching the requested
    /// binding whose protocol version shares a major version with
    /// `protocolVersion`. An interface that declares no version is treated as
    /// compatible, since proto3 JSON serializers omit default-valued fields.
    public static func selectInterface(
        from card: AgentCard,
        binding: String = AgentInterface.Binding.jsonrpc,
        protocolVersion: String = A2AProtocol.version
    ) -> AgentInterface? {
        card.supportedInterfaces.first { interface in
            interface.protocolBinding == binding
                && (interface.protocolVersion.isEmpty
                    || majorVersion(of: interface.protocolVersion) == majorVersion(of: protocolVersion))
        }
    }

    private static func majorVersion(of version: String) -> Substring {
        version.split(separator: ".", maxSplits: 1).first ?? Substring(version)
    }
}
