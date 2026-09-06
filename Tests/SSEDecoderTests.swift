import XCTest
@testable import Odyssey

final class SSEDecoderTests: XCTestCase {
    func testUTF8BOMAndEveryByteBoundary() throws {
        let source = "\u{feff}event: text\r\ndata: 中文🌏e\u{301}\r\n\r\n"
        XCTAssertEqual(try decode(source), [ServerSentEvent(name: "text", data: "中文🌏e\u{301}")])
    }

    func testLFCRLFAndBareCRLineEndings() throws {
        for newline in ["\n", "\r\n", "\r"] {
            XCTAssertEqual(try decode("data: A" + newline + newline + "data: B" + newline + newline),
                           [ServerSentEvent(name: "message", data: "A"), ServerSentEvent(name: "message", data: "B")])
        }
    }

    func testMultilineDataCommentsAndIgnoredReconnectFields() throws {
        let events = try decode(": keep alive\nid: ignored\nretry: 1\nevent: first\nevent: last\ndata: {\ndata:   \"x\": 1\ndata: }\n\n")
        XCTAssertEqual(events, [ServerSentEvent(name: "last", data: "{\n  \"x\": 1\n}")])
    }

    func testOnlyOneLeadingSpaceIsRemoved() throws {
        XCTAssertEqual(try decode("data:  a:b\n\n").first?.data, " a:b")
        XCTAssertEqual(try decode("data:\ta\n\n").first?.data, "\ta")
    }

    func testEmptyDataDispatchesButEmptyBlocksDoNot() throws {
        XCTAssertEqual(try decode("\n: comment\n\nevent: unused\n\ndata\n\n"),
                       [ServerSentEvent(name: "message", data: "")])
    }

    func testEventNameDoesNotLeakToNextEvent() throws {
        XCTAssertEqual(try decode("event: one\ndata: 1\n\ndata: 2\n\n").map(\.name), ["one", "message"])
    }

    func testEOFNeverFlushesUnterminatedEvent() throws {
        XCTAssertTrue(try decode("data: not-complete").isEmpty)
        XCTAssertTrue(try decode("data: not-complete\n").isEmpty)
    }

    func testInvalidUTF8FailsInsteadOfReplacingCharacters() throws {
        var parser = SSEDecoder()
        for byte in Array("data: ".utf8) + [0xF0, 0x9F] { _ = try parser.append(byte) }
        XCTAssertThrowsError(try parser.append(10)) { XCTAssertEqual($0 as? StreamingError, .invalidEvent) }
    }

    func testMemoryLimitAlsoAppliesToCommentsAndUnknownFields() {
        for source in ["data: too-long", ": comment-too-long", "unknown: too-long"] {
            XCTAssertThrowsError(try decode(source, limit: 8)) { XCTAssertEqual($0 as? StreamingError, .responseTooLarge) }
        }
    }

    func testEventBudgetResetsAtBlankLine() throws {
        XCTAssertEqual(try decode("data: a\n\ndata: b\n\n", limit: 9).count, 2)
    }

    private func decode(_ source: String, limit: Int = 1024) throws -> [ServerSentEvent] {
        var parser = SSEDecoder(maximumEventBytes: limit)
        return try source.utf8.compactMap { try parser.append($0) }
    }
}
