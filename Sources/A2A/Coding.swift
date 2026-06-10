import Foundation

/// Factories for JSON coders configured for A2A wire format.
///
/// A2A JSON uses the proto3 JSON mapping: camelCase keys (already matched by
/// the Swift property names — no key strategy needed), proto-name enum strings,
/// base64 for bytes, and ISO 8601 strings for timestamps.
public enum A2AJSON {
    /// A `JSONEncoder` producing deterministic, A2A-conformant output.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// A `JSONDecoder` for A2A wire format.
    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }
}
