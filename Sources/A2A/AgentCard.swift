import Foundation

/// A target URL, protocol binding, and protocol version for interacting with
/// the agent (`lf.a2a.v1.AgentInterface`).
public struct AgentInterface: Sendable, Codable, Equatable {
    /// Officially supported protocol binding identifiers.
    public enum Binding {
        public static let jsonrpc = "JSONRPC"
        public static let grpc = "GRPC"
        public static let httpJSON = "HTTP+JSON"
    }

    /// The URL where this interface is available. Must be an absolute HTTPS URL in production.
    public var url: String
    /// The protocol binding supported at this URL, e.g. `JSONRPC`, `GRPC`, `HTTP+JSON`.
    public var protocolBinding: String
    /// Opaque routing identifier. When set, clients MUST include this value in
    /// the `tenant` field of all request messages sent to this interface.
    public var tenant: String?
    /// The version of the A2A protocol this interface exposes, e.g. "1.0".
    public var protocolVersion: String

    public init(
        url: String,
        protocolBinding: String,
        tenant: String? = nil,
        protocolVersion: String
    ) {
        self.url = url
        self.protocolBinding = protocolBinding
        self.tenant = tenant
        self.protocolVersion = protocolVersion
    }

    private enum CodingKeys: String, CodingKey {
        case url, protocolBinding, tenant, protocolVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        protocolBinding = try container.decode(String.self, forKey: .protocolBinding)
        tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        // The field is REQUIRED by spec, but proto3 JSON serializers omit
        // default-valued strings; the reference SDKs emit cards without it.
        protocolVersion = try container.decodeIfPresent(String.self, forKey: .protocolVersion) ?? ""
    }
}

/// The service provider of an agent (`lf.a2a.v1.AgentProvider`).
public struct AgentProvider: Sendable, Codable, Equatable {
    /// A URL for the provider's website or relevant documentation.
    public var url: String
    /// The name of the provider's organization.
    public var organization: String

    public init(url: String, organization: String) {
        self.url = url
        self.organization = organization
    }
}

/// A declaration of a protocol extension supported by an agent (`lf.a2a.v1.AgentExtension`).
public struct AgentExtension: Sendable, Codable, Equatable {
    /// The unique URI identifying the extension.
    public var uri: String
    /// A human-readable description of how this agent uses the extension.
    public var description: String?
    /// If true, the client must understand and comply with the extension's requirements.
    public var required: Bool
    /// Extension-specific configuration parameters.
    public var params: [String: JSONValue]?

    public init(
        uri: String,
        description: String? = nil,
        required: Bool = false,
        params: [String: JSONValue]? = nil
    ) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }

    private enum CodingKeys: String, CodingKey {
        case uri, description, required, params
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = try container.decode(String.self, forKey: .uri)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        params = try container.decodeIfPresent([String: JSONValue].self, forKey: .params)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uri, forKey: .uri)
        try container.encodeIfPresent(description, forKey: .description)
        if required {
            try container.encode(required, forKey: .required)
        }
        try container.encodeIfPresent(params, forKey: .params)
    }
}

/// Optional capabilities supported by an agent (`lf.a2a.v1.AgentCapabilities`).
public struct AgentCapabilities: Sendable, Codable, Equatable {
    /// Indicates if the agent supports streaming responses.
    public var streaming: Bool?
    /// Indicates if the agent supports push notifications for asynchronous task updates.
    public var pushNotifications: Bool?
    /// A list of protocol extensions supported by the agent.
    public var extensions: [AgentExtension]
    /// Indicates if the agent supports providing an extended agent card when authenticated.
    public var extendedAgentCard: Bool?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        extensions: [AgentExtension] = [],
        extendedAgentCard: Bool? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.extensions = extensions
        self.extendedAgentCard = extendedAgentCard
    }

    private enum CodingKeys: String, CodingKey {
        case streaming, pushNotifications, extensions, extendedAgentCard
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)
        pushNotifications = try container.decodeIfPresent(Bool.self, forKey: .pushNotifications)
        extensions = try container.decodeIfPresent([AgentExtension].self, forKey: .extensions) ?? []
        extendedAgentCard = try container.decodeIfPresent(Bool.self, forKey: .extendedAgentCard)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(streaming, forKey: .streaming)
        try container.encodeIfPresent(pushNotifications, forKey: .pushNotifications)
        if !extensions.isEmpty {
            try container.encode(extensions, forKey: .extensions)
        }
        try container.encodeIfPresent(extendedAgentCard, forKey: .extendedAgentCard)
    }
}

/// A distinct capability or function an agent can perform (`lf.a2a.v1.AgentSkill`).
public struct AgentSkill: Sendable, Codable, Equatable {
    /// A unique identifier for the skill.
    public var id: String
    /// A human-readable name for the skill.
    public var name: String
    /// A detailed description of the skill.
    public var description: String
    /// Keywords describing the skill's capabilities.
    public var tags: [String]
    /// Example prompts or scenarios that this skill can handle.
    public var examples: [String]
    /// Supported input media types for this skill, overriding the agent's defaults.
    public var inputModes: [String]
    /// Supported output media types for this skill, overriding the agent's defaults.
    public var outputModes: [String]
    /// Security schemes necessary for this skill.
    public var securityRequirements: [SecurityRequirement]

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String],
        examples: [String] = [],
        inputModes: [String] = [],
        outputModes: [String] = [],
        securityRequirements: [SecurityRequirement] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.securityRequirements = securityRequirements
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, tags, examples, inputModes, outputModes, securityRequirements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        examples = try container.decodeIfPresent([String].self, forKey: .examples) ?? []
        inputModes = try container.decodeIfPresent([String].self, forKey: .inputModes) ?? []
        outputModes = try container.decodeIfPresent([String].self, forKey: .outputModes) ?? []
        securityRequirements =
            try container.decodeIfPresent([SecurityRequirement].self, forKey: .securityRequirements) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        if !examples.isEmpty {
            try container.encode(examples, forKey: .examples)
        }
        if !inputModes.isEmpty {
            try container.encode(inputModes, forKey: .inputModes)
        }
        if !outputModes.isEmpty {
            try container.encode(outputModes, forKey: .outputModes)
        }
        if !securityRequirements.isEmpty {
            try container.encode(securityRequirements, forKey: .securityRequirements)
        }
    }
}

/// A JWS signature of an agent card per RFC 7515 (`lf.a2a.v1.AgentCardSignature`).
public struct AgentCardSignature: Sendable, Codable, Equatable {
    /// The protected JWS header for the signature, a base64url-encoded JSON object.
    public var protected: String
    /// The computed signature, base64url-encoded.
    public var signature: String
    /// The unprotected JWS header values.
    public var header: [String: JSONValue]?

    public init(protected: String, signature: String, header: [String: JSONValue]? = nil) {
        self.protected = protected
        self.signature = signature
        self.header = header
    }
}

/// A self-describing manifest for an agent (`lf.a2a.v1.AgentCard`).
///
/// Published at `https://{domain}/.well-known/agent-card.json`.
public struct AgentCard: Sendable, Codable, Equatable {
    /// A human readable name for the agent, e.g. "Recipe Agent".
    public var name: String
    /// A human-readable description of the agent.
    public var description: String
    /// Ordered list of supported interfaces. The first entry is preferred.
    public var supportedInterfaces: [AgentInterface]
    /// The service provider of the agent.
    public var provider: AgentProvider?
    /// The version of the agent, e.g. "1.0.0".
    public var version: String
    /// A URL providing additional documentation about the agent.
    public var documentationUrl: String?
    /// A2A capability set supported by the agent.
    public var capabilities: AgentCapabilities
    /// The security scheme details used for authenticating with this agent.
    public var securitySchemes: [String: SecurityScheme]?
    /// Security requirements for contacting the agent.
    public var securityRequirements: [SecurityRequirement]
    /// Interaction modes the agent supports across all skills, as media types.
    public var defaultInputModes: [String]
    /// Media types supported as outputs from this agent.
    public var defaultOutputModes: [String]
    /// The abilities of the agent.
    public var skills: [AgentSkill]
    /// JSON Web Signatures computed for this card.
    public var signatures: [AgentCardSignature]
    /// A URL to an icon for the agent.
    public var iconUrl: String?

    public init(
        name: String,
        description: String,
        supportedInterfaces: [AgentInterface],
        provider: AgentProvider? = nil,
        version: String,
        documentationUrl: String? = nil,
        capabilities: AgentCapabilities,
        securitySchemes: [String: SecurityScheme]? = nil,
        securityRequirements: [SecurityRequirement] = [],
        defaultInputModes: [String],
        defaultOutputModes: [String],
        skills: [AgentSkill],
        signatures: [AgentCardSignature] = [],
        iconUrl: String? = nil
    ) {
        self.name = name
        self.description = description
        self.supportedInterfaces = supportedInterfaces
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.securityRequirements = securityRequirements
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.signatures = signatures
        self.iconUrl = iconUrl
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, supportedInterfaces, provider, version, documentationUrl
        case capabilities, securitySchemes, securityRequirements
        case defaultInputModes, defaultOutputModes, skills, signatures, iconUrl
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        supportedInterfaces =
            try container.decodeIfPresent([AgentInterface].self, forKey: .supportedInterfaces) ?? []
        provider = try container.decodeIfPresent(AgentProvider.self, forKey: .provider)
        version = try container.decode(String.self, forKey: .version)
        documentationUrl = try container.decodeIfPresent(String.self, forKey: .documentationUrl)
        capabilities =
            try container.decodeIfPresent(AgentCapabilities.self, forKey: .capabilities)
            ?? AgentCapabilities()
        securitySchemes =
            try container.decodeIfPresent([String: SecurityScheme].self, forKey: .securitySchemes)
        securityRequirements =
            try container.decodeIfPresent([SecurityRequirement].self, forKey: .securityRequirements) ?? []
        defaultInputModes = try container.decodeIfPresent([String].self, forKey: .defaultInputModes) ?? []
        defaultOutputModes = try container.decodeIfPresent([String].self, forKey: .defaultOutputModes) ?? []
        skills = try container.decodeIfPresent([AgentSkill].self, forKey: .skills) ?? []
        signatures = try container.decodeIfPresent([AgentCardSignature].self, forKey: .signatures) ?? []
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(supportedInterfaces, forKey: .supportedInterfaces)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(documentationUrl, forKey: .documentationUrl)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(securitySchemes, forKey: .securitySchemes)
        if !securityRequirements.isEmpty {
            try container.encode(securityRequirements, forKey: .securityRequirements)
        }
        try container.encode(defaultInputModes, forKey: .defaultInputModes)
        try container.encode(defaultOutputModes, forKey: .defaultOutputModes)
        try container.encode(skills, forKey: .skills)
        if !signatures.isEmpty {
            try container.encode(signatures, forKey: .signatures)
        }
        try container.encodeIfPresent(iconUrl, forKey: .iconUrl)
    }
}
