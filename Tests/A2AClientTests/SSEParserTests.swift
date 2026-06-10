import Foundation
import Testing

@testable import A2AClient

@Suite("SSEParser")
struct SSEParserTests {
    @Test func singleEvent() {
        var parser = SSEParser()
        let events = parser.feed(Data("data: hello\n\n".utf8))
        #expect(events == [SSEEvent(data: "hello")])
    }

    @Test func multipleEventsInOneChunk() {
        var parser = SSEParser()
        let events = parser.feed(Data("data: one\n\ndata: two\n\ndata: three\n\n".utf8))
        #expect(events.map(\.data) == ["one", "two", "three"])
    }

    @Test func eventSplitAcrossChunks() {
        var parser = SSEParser()
        #expect(parser.feed(Data("da".utf8)).isEmpty)
        #expect(parser.feed(Data("ta: hel".utf8)).isEmpty)
        #expect(parser.feed(Data("lo\n".utf8)).isEmpty)
        let events = parser.feed(Data("\n".utf8))
        #expect(events.map(\.data) == ["hello"])
    }

    @Test func multiByteUTF8SplitAcrossChunks() {
        var parser = SSEParser()
        let bytes = Array("data: caf\u{E9}\n\n".utf8)
        // Split inside the two-byte UTF-8 sequence for é.
        let splitIndex = bytes.count - 3
        #expect(parser.feed(Data(bytes[..<splitIndex])).isEmpty)
        let events = parser.feed(Data(bytes[splitIndex...]))
        #expect(events.map(\.data) == ["café"])
    }

    @Test func crlfLineEndings() {
        var parser = SSEParser()
        let events = parser.feed(Data("data: hello\r\n\r\n".utf8))
        #expect(events.map(\.data) == ["hello"])
    }

    @Test func commentsAreIgnored() {
        var parser = SSEParser()
        let events = parser.feed(Data(": keep-alive\n\ndata: real\n\n".utf8))
        #expect(events.map(\.data) == ["real"])
    }

    @Test func multiLineDataJoinsWithNewline() {
        var parser = SSEParser()
        let events = parser.feed(Data("data: line one\ndata: line two\n\n".utf8))
        #expect(events.map(\.data) == ["line one\nline two"])
    }

    @Test func eventTypeIdAndRetry() {
        var parser = SSEParser()
        let events = parser.feed(Data("event: update\nid: 7\nretry: 3000\ndata: x\n\n".utf8))
        #expect(events == [SSEEvent(event: "update", data: "x", id: "7", retry: 3000)])
    }

    @Test func eventTypeResetsBetweenEvents() {
        var parser = SSEParser()
        let events = parser.feed(Data("event: a\ndata: 1\n\ndata: 2\n\n".utf8))
        #expect(events.count == 2)
        #expect(events[0].event == "a")
        #expect(events[1].event == nil)
        // The id field persists (last event ID semantics).
        #expect(events[1].id == events[0].id)
    }

    @Test func blankLinesWithoutDataDispatchNothing() {
        var parser = SSEParser()
        #expect(parser.feed(Data("\n\n\n".utf8)).isEmpty)
    }

    @Test func noSpaceAfterColon() {
        var parser = SSEParser()
        let events = parser.feed(Data("data:tight\n\n".utf8))
        #expect(events.map(\.data) == ["tight"])
    }

    @Test func fieldWithoutColonHasEmptyValue() {
        var parser = SSEParser()
        let events = parser.feed(Data("data\n\n".utf8))
        #expect(events.map(\.data) == [""])
    }
}
