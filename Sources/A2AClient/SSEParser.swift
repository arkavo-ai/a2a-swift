import Foundation

/// A single Server-Sent Event.
public struct SSEEvent: Sendable, Equatable {
    /// The `event` field, if set.
    public var event: String?
    /// The concatenated `data` field. Multi-line data is joined with "\n".
    public var data: String
    /// The `id` field, if set.
    public var id: String?
    /// The `retry` field in milliseconds, if set and numeric.
    public var retry: Int?

    public init(event: String? = nil, data: String, id: String? = nil, retry: Int? = nil) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
}

/// An incremental Server-Sent Events parser (WHATWG HTML event-stream format).
///
/// Feed arbitrary byte chunks as they arrive; complete events are returned as
/// they are dispatched by a blank line. Handles events split across chunk
/// boundaries, CRLF and LF line endings, `:` comment lines, and multi-line
/// `data` fields. Splitting only on the LF byte keeps multi-byte UTF-8
/// sequences intact across chunks.
public struct SSEParser: Sendable {
    private var buffer: [UInt8] = []
    private var dataLines: [String] = []
    private var eventType: String?
    private var lastEventID: String?
    private var retry: Int?

    public init() {}

    /// Consumes a chunk of bytes and returns any events completed by it.
    public mutating func feed(_ chunk: Data) -> [SSEEvent] {
        buffer.append(contentsOf: chunk)
        var events: [SSEEvent] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            var lineBytes = Array(buffer[..<newlineIndex])
            buffer.removeFirst(newlineIndex + 1)
            if lineBytes.last == 0x0D {
                lineBytes.removeLast()
            }
            if let event = process(line: String(decoding: lineBytes, as: UTF8.self)) {
                events.append(event)
            }
        }
        return events
    }

    /// Signals end of stream. Per the SSE specification an event is only
    /// dispatched by a blank line, so any partially accumulated event is
    /// discarded; this resets the parser and returns nothing.
    public mutating func finish() {
        buffer.removeAll()
        dataLines.removeAll()
        eventType = nil
        retry = nil
    }

    private mutating func process(line: String) -> SSEEvent? {
        if line.isEmpty {
            return dispatch()
        }
        if line.hasPrefix(":") {
            return nil
        }
        let field: Substring
        let value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            var rest = line[line.index(after: colon)...]
            if rest.hasPrefix(" ") {
                rest = rest.dropFirst()
            }
            value = rest
        } else {
            field = line[...]
            value = ""
        }
        switch field {
        case "data":
            dataLines.append(String(value))
        case "event":
            eventType = String(value)
        case "id":
            // Per spec, ignore ids containing NUL.
            if !value.contains("\u{0}") {
                lastEventID = String(value)
            }
        case "retry":
            if let milliseconds = Int(value) {
                retry = milliseconds
            }
        default:
            break
        }
        return nil
    }

    private mutating func dispatch() -> SSEEvent? {
        defer {
            dataLines.removeAll()
            eventType = nil
        }
        guard !dataLines.isEmpty else {
            return nil
        }
        return SSEEvent(
            event: eventType,
            data: dataLines.joined(separator: "\n"),
            id: lastEventID,
            retry: retry
        )
    }
}
