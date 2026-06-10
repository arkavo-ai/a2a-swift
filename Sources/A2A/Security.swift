import Foundation

/// A list of strings (`lf.a2a.v1.StringList`), used as the value type in
/// `SecurityRequirement.schemes`.
public struct StringList: Sendable, Codable, Equatable {
    /// The individual string values.
    public var list: [String]

    public init(list: [String] = []) {
        self.list = list
    }

    private enum CodingKeys: String, CodingKey {
        case list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = try container.decodeIfPresent([String].self, forKey: .list) ?? []
    }
}

/// The security requirements for an agent (`lf.a2a.v1.SecurityRequirement`).
public struct SecurityRequirement: Sendable, Codable, Equatable {
    /// A map of security scheme names to the required scopes.
    public var schemes: [String: StringList]

    public init(schemes: [String: StringList] = [:]) {
        self.schemes = schemes
    }

    private enum CodingKeys: String, CodingKey {
        case schemes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemes = try container.decodeIfPresent([String: StringList].self, forKey: .schemes) ?? [:]
    }
}

/// API key-based authentication (`lf.a2a.v1.APIKeySecurityScheme`).
public struct APIKeySecurityScheme: Sendable, Codable, Equatable {
    /// An optional description for the security scheme.
    public var description: String?
    /// The location of the API key: "query", "header", or "cookie".
    public var location: String
    /// The name of the header, query, or cookie parameter to be used.
    public var name: String

    public init(description: String? = nil, location: String, name: String) {
        self.description = description
        self.location = location
        self.name = name
    }
}

/// HTTP authentication (`lf.a2a.v1.HTTPAuthSecurityScheme`).
public struct HTTPAuthSecurityScheme: Sendable, Codable, Equatable {
    /// An optional description for the security scheme.
    public var description: String?
    /// The HTTP authentication scheme used in the Authorization header, e.g. "Bearer".
    public var scheme: String
    /// A hint to the client to identify how the bearer token is formatted, e.g. "JWT".
    public var bearerFormat: String?

    public init(description: String? = nil, scheme: String, bearerFormat: String? = nil) {
        self.description = description
        self.scheme = scheme
        self.bearerFormat = bearerFormat
    }
}

/// OAuth 2.0 authentication (`lf.a2a.v1.OAuth2SecurityScheme`).
public struct OAuth2SecurityScheme: Sendable, Codable, Equatable {
    /// An optional description for the security scheme.
    public var description: String?
    /// Configuration information for the supported OAuth 2.0 flows.
    public var flows: OAuthFlows
    /// URL to the OAuth2 authorization server metadata (RFC 8414). TLS is required.
    public var oauth2MetadataUrl: String?

    public init(description: String? = nil, flows: OAuthFlows, oauth2MetadataUrl: String? = nil) {
        self.description = description
        self.flows = flows
        self.oauth2MetadataUrl = oauth2MetadataUrl
    }
}

/// OpenID Connect authentication (`lf.a2a.v1.OpenIdConnectSecurityScheme`).
public struct OpenIdConnectSecurityScheme: Sendable, Codable, Equatable {
    /// An optional description for the security scheme.
    public var description: String?
    /// The OpenID Connect Discovery URL for the OIDC provider's metadata.
    public var openIdConnectUrl: String

    public init(description: String? = nil, openIdConnectUrl: String) {
        self.description = description
        self.openIdConnectUrl = openIdConnectUrl
    }
}

/// Mutual TLS authentication (`lf.a2a.v1.MutualTlsSecurityScheme`).
public struct MutualTLSSecurityScheme: Sendable, Codable, Equatable {
    /// An optional description for the security scheme.
    public var description: String?

    public init(description: String? = nil) {
        self.description = description
    }
}

/// A security scheme for an agent's endpoints (`lf.a2a.v1.SecurityScheme`).
///
/// A discriminated union based on the OpenAPI 3.2 Security Scheme Object.
/// In JSON, exactly one of the scheme keys is present.
public enum SecurityScheme: Sendable, Codable, Equatable {
    case apiKey(APIKeySecurityScheme)
    case httpAuth(HTTPAuthSecurityScheme)
    case oauth2(OAuth2SecurityScheme)
    case openIdConnect(OpenIdConnectSecurityScheme)
    case mtls(MutualTLSSecurityScheme)

    private enum CodingKeys: String, CodingKey {
        case apiKeySecurityScheme
        case httpAuthSecurityScheme
        case oauth2SecurityScheme
        case openIdConnectSecurityScheme
        case mtlsSecurityScheme
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let scheme = try container.decodeIfPresent(
            APIKeySecurityScheme.self, forKey: .apiKeySecurityScheme)
        {
            self = .apiKey(scheme)
        } else if let scheme = try container.decodeIfPresent(
            HTTPAuthSecurityScheme.self, forKey: .httpAuthSecurityScheme)
        {
            self = .httpAuth(scheme)
        } else if let scheme = try container.decodeIfPresent(
            OAuth2SecurityScheme.self, forKey: .oauth2SecurityScheme)
        {
            self = .oauth2(scheme)
        } else if let scheme = try container.decodeIfPresent(
            OpenIdConnectSecurityScheme.self, forKey: .openIdConnectSecurityScheme)
        {
            self = .openIdConnect(scheme)
        } else if let scheme = try container.decodeIfPresent(
            MutualTLSSecurityScheme.self, forKey: .mtlsSecurityScheme)
        {
            self = .mtls(scheme)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "SecurityScheme must contain exactly one scheme variant"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .apiKey(let scheme):
            try container.encode(scheme, forKey: .apiKeySecurityScheme)
        case .httpAuth(let scheme):
            try container.encode(scheme, forKey: .httpAuthSecurityScheme)
        case .oauth2(let scheme):
            try container.encode(scheme, forKey: .oauth2SecurityScheme)
        case .openIdConnect(let scheme):
            try container.encode(scheme, forKey: .openIdConnectSecurityScheme)
        case .mtls(let scheme):
            try container.encode(scheme, forKey: .mtlsSecurityScheme)
        }
    }
}

// MARK: - OAuth flows

/// Configuration for the OAuth 2.0 Authorization Code flow (`lf.a2a.v1.AuthorizationCodeOAuthFlow`).
public struct AuthorizationCodeOAuthFlow: Sendable, Codable, Equatable {
    /// The authorization URL to be used for this flow.
    public var authorizationUrl: String
    /// The token URL to be used for this flow.
    public var tokenUrl: String
    /// The URL to be used for obtaining refresh tokens.
    public var refreshUrl: String?
    /// The available scopes, mapping scope name to a short description.
    public var scopes: [String: String]
    /// Indicates if PKCE (RFC 7636) is required for this flow.
    public var pkceRequired: Bool

    public init(
        authorizationUrl: String,
        tokenUrl: String,
        refreshUrl: String? = nil,
        scopes: [String: String],
        pkceRequired: Bool = false
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
        self.pkceRequired = pkceRequired
    }

    private enum CodingKeys: String, CodingKey {
        case authorizationUrl, tokenUrl, refreshUrl, scopes, pkceRequired
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorizationUrl = try container.decode(String.self, forKey: .authorizationUrl)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
        pkceRequired = try container.decodeIfPresent(Bool.self, forKey: .pkceRequired) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationUrl, forKey: .authorizationUrl)
        try container.encode(tokenUrl, forKey: .tokenUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        try container.encode(scopes, forKey: .scopes)
        if pkceRequired {
            try container.encode(pkceRequired, forKey: .pkceRequired)
        }
    }
}

/// Configuration for the OAuth 2.0 Client Credentials flow (`lf.a2a.v1.ClientCredentialsOAuthFlow`).
public struct ClientCredentialsOAuthFlow: Sendable, Codable, Equatable {
    /// The token URL to be used for this flow.
    public var tokenUrl: String
    /// The URL to be used for obtaining refresh tokens.
    public var refreshUrl: String?
    /// The available scopes, mapping scope name to a short description.
    public var scopes: [String: String]

    public init(tokenUrl: String, refreshUrl: String? = nil, scopes: [String: String]) {
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey {
        case tokenUrl, refreshUrl, scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }
}

/// Configuration for the deprecated OAuth 2.0 Implicit flow (`lf.a2a.v1.ImplicitOAuthFlow`).
///
/// Deprecated upstream: use Authorization Code + PKCE instead.
public struct ImplicitOAuthFlow: Sendable, Codable, Equatable {
    /// The authorization URL to be used for this flow.
    public var authorizationUrl: String?
    /// The URL to be used for obtaining refresh tokens.
    public var refreshUrl: String?
    /// The available scopes, mapping scope name to a short description.
    public var scopes: [String: String]

    public init(authorizationUrl: String? = nil, refreshUrl: String? = nil, scopes: [String: String] = [:]) {
        self.authorizationUrl = authorizationUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey {
        case authorizationUrl, refreshUrl, scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorizationUrl = try container.decodeIfPresent(String.self, forKey: .authorizationUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }
}

/// Configuration for the deprecated OAuth 2.0 Password flow (`lf.a2a.v1.PasswordOAuthFlow`).
///
/// Deprecated upstream: use Authorization Code + PKCE or Device Code.
public struct PasswordOAuthFlow: Sendable, Codable, Equatable {
    /// The token URL to be used for this flow.
    public var tokenUrl: String?
    /// The URL to be used for obtaining refresh tokens.
    public var refreshUrl: String?
    /// The available scopes, mapping scope name to a short description.
    public var scopes: [String: String]

    public init(tokenUrl: String? = nil, refreshUrl: String? = nil, scopes: [String: String] = [:]) {
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey {
        case tokenUrl, refreshUrl, scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenUrl = try container.decodeIfPresent(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }
}

/// Configuration for the OAuth 2.0 Device Code flow, RFC 8628 (`lf.a2a.v1.DeviceCodeOAuthFlow`).
public struct DeviceCodeOAuthFlow: Sendable, Codable, Equatable {
    /// The device authorization endpoint URL.
    public var deviceAuthorizationUrl: String
    /// The token URL to be used for this flow.
    public var tokenUrl: String
    /// The URL to be used for obtaining refresh tokens.
    public var refreshUrl: String?
    /// The available scopes, mapping scope name to a short description.
    public var scopes: [String: String]

    public init(
        deviceAuthorizationUrl: String,
        tokenUrl: String,
        refreshUrl: String? = nil,
        scopes: [String: String]
    ) {
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey {
        case deviceAuthorizationUrl, tokenUrl, refreshUrl, scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceAuthorizationUrl = try container.decode(String.self, forKey: .deviceAuthorizationUrl)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }
}

/// Configuration for the supported OAuth 2.0 flows (`lf.a2a.v1.OAuthFlows`).
///
/// A oneof: in JSON, exactly one flow key is present.
public enum OAuthFlows: Sendable, Codable, Equatable {
    case authorizationCode(AuthorizationCodeOAuthFlow)
    case clientCredentials(ClientCredentialsOAuthFlow)
    /// Deprecated upstream: use Authorization Code + PKCE instead.
    case implicit(ImplicitOAuthFlow)
    /// Deprecated upstream: use Authorization Code + PKCE or Device Code.
    case password(PasswordOAuthFlow)
    case deviceCode(DeviceCodeOAuthFlow)

    private enum CodingKeys: String, CodingKey {
        case authorizationCode, clientCredentials, implicit, password, deviceCode
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let flow = try container.decodeIfPresent(
            AuthorizationCodeOAuthFlow.self, forKey: .authorizationCode)
        {
            self = .authorizationCode(flow)
        } else if let flow = try container.decodeIfPresent(
            ClientCredentialsOAuthFlow.self, forKey: .clientCredentials)
        {
            self = .clientCredentials(flow)
        } else if let flow = try container.decodeIfPresent(ImplicitOAuthFlow.self, forKey: .implicit) {
            self = .implicit(flow)
        } else if let flow = try container.decodeIfPresent(PasswordOAuthFlow.self, forKey: .password) {
            self = .password(flow)
        } else if let flow = try container.decodeIfPresent(DeviceCodeOAuthFlow.self, forKey: .deviceCode) {
            self = .deviceCode(flow)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "OAuthFlows must contain exactly one flow variant"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .authorizationCode(let flow):
            try container.encode(flow, forKey: .authorizationCode)
        case .clientCredentials(let flow):
            try container.encode(flow, forKey: .clientCredentials)
        case .implicit(let flow):
            try container.encode(flow, forKey: .implicit)
        case .password(let flow):
            try container.encode(flow, forKey: .password)
        case .deviceCode(let flow):
            try container.encode(flow, forKey: .deviceCode)
        }
    }
}
