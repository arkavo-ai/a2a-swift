import Foundation

/// Identifies the sender of a message (`lf.a2a.v1.Role`).
///
/// Serialized using the proto3 JSON enum mapping, e.g. `"ROLE_USER"`.
public enum Role: String, Sendable, Codable, CaseIterable {
    case unspecified = "ROLE_UNSPECIFIED"
    case user = "ROLE_USER"
    case agent = "ROLE_AGENT"
}

/// A container for a section of communication content (`lf.a2a.v1.Part`).
///
/// The content is a oneof: exactly one of `text`, `raw`, `url`, or `data` appears
/// as a key in the JSON object, alongside the optional shared fields.
public struct Part: Sendable, Codable, Equatable {
    /// The `content` oneof. In JSON, the case name is the object key.
    public enum Content: Sendable, Equatable {
        /// The string content of the `text` part.
        case text(String)
        /// The raw byte content of a file. Encoded as a base64 string in JSON.
        case raw(Data)
        /// A URL pointing to the file's content.
        case url(String)
        /// Arbitrary structured data as a JSON value.
        case data(JSONValue)
    }

    public var content: Content
    /// Metadata associated with this part.
    public var metadata: [String: JSONValue]?
    /// An optional filename for the file (e.g. "document.pdf").
    public var filename: String?
    /// The media type (MIME type) of the part content. Available for all part types.
    public var mediaType: String?

    public init(
        content: Content,
        metadata: [String: JSONValue]? = nil,
        filename: String? = nil,
        mediaType: String? = nil
    ) {
        self.content = content
        self.metadata = metadata
        self.filename = filename
        self.mediaType = mediaType
    }

    /// A plain text part.
    public static func text(_ text: String, mediaType: String? = nil) -> Part {
        Part(content: .text(text), mediaType: mediaType)
    }

    /// A file part carrying raw bytes.
    public static func raw(_ bytes: Data, filename: String? = nil, mediaType: String? = nil) -> Part {
        Part(content: .raw(bytes), filename: filename, mediaType: mediaType)
    }

    /// A file part referenced by URL.
    public static func url(_ url: String, filename: String? = nil, mediaType: String? = nil) -> Part {
        Part(content: .url(url), filename: filename, mediaType: mediaType)
    }

    /// A structured data part.
    public static func data(_ value: JSONValue, mediaType: String? = nil) -> Part {
        Part(content: .data(value), mediaType: mediaType)
    }

    private enum CodingKeys: String, CodingKey {
        case text, raw, url, data, metadata, filename, mediaType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            content = .text(text)
        } else if let base64 = try container.decodeIfPresent(String.self, forKey: .raw) {
            guard let bytes = Data(base64Encoded: base64) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .raw,
                    in: container,
                    debugDescription: "Invalid base64 in Part.raw"
                )
            }
            content = .raw(bytes)
        } else if let url = try container.decodeIfPresent(String.self, forKey: .url) {
            content = .url(url)
        } else if container.contains(.data) {
            // Not decodeIfPresent: an explicit JSON null is a valid Value here.
            content = .data(try container.decode(JSONValue.self, forKey: .data))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Part must contain one of: text, raw, url, data"
                )
            )
        }
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .raw(let bytes):
            try container.encode(bytes.base64EncodedString(), forKey: .raw)
        case .url(let url):
            try container.encode(url, forKey: .url)
        case .data(let data):
            try container.encode(data, forKey: .data)
        }
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
    }
}

/// One unit of communication between client and server (`lf.a2a.v1.Message`).
public struct Message: Sendable, Codable, Equatable {
    /// The unique identifier (e.g. UUID) of the message, created by the message creator.
    public var messageId: String
    /// The context id of the message, associating it with a conversation.
    public var contextId: String?
    /// The task id of the message, associating it with a task.
    public var taskId: String?
    /// Identifies the sender of the message.
    public var role: Role
    /// The container of the message content.
    public var parts: [Part]
    /// Any metadata to provide along with the message.
    public var metadata: [String: JSONValue]?
    /// The URIs of extensions that are present or contributed to this message.
    public var extensions: [String]
    /// A list of task IDs that this message references for additional context.
    public var referenceTaskIds: [String]

    public init(
        messageId: String,
        contextId: String? = nil,
        taskId: String? = nil,
        role: Role,
        parts: [Part],
        metadata: [String: JSONValue]? = nil,
        extensions: [String] = [],
        referenceTaskIds: [String] = []
    ) {
        self.messageId = messageId
        self.contextId = contextId
        self.taskId = taskId
        self.role = role
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
        self.referenceTaskIds = referenceTaskIds
    }

    private enum CodingKeys: String, CodingKey {
        case messageId, contextId, taskId, role, parts, metadata, extensions, referenceTaskIds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(String.self, forKey: .messageId)
        contextId = try container.decodeIfPresent(String.self, forKey: .contextId)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        role = try container.decode(Role.self, forKey: .role)
        parts = try container.decodeIfPresent([Part].self, forKey: .parts) ?? []
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
        referenceTaskIds = try container.decodeIfPresent([String].self, forKey: .referenceTaskIds) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encodeIfPresent(contextId, forKey: .contextId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encode(role, forKey: .role)
        try container.encode(parts, forKey: .parts)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        if !extensions.isEmpty {
            try container.encode(extensions, forKey: .extensions)
        }
        if !referenceTaskIds.isEmpty {
            try container.encode(referenceTaskIds, forKey: .referenceTaskIds)
        }
    }
}
