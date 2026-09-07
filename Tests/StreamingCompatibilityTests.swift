import XCTest
@testable import Odyssey

final class StreamingCompatibilityTests: XCTestCase {
    func testCustomEndpointMatrixPreservesPathPortAndProtocol() throws {
        let paths = ["https://gateway.invalid", "https://gateway.invalid/", "https://gateway.invalid:8443/proxy/v1///",
                     "https://gateway.invalid/tenant%2Fname/api%20path/v9/"]
        for format in APIFormat.allCases {
            for base in paths {
                let config = APIConfiguration(apiFormat: format, baseURL: base, modelID: "custom/model-alias")
                let probe = try APIProbeRequestBuilder.build(configuration: config, apiKey: StreamingFixtures.key, outputLimit: 256)
                let stream = try StreamingRequestBuilder.build(configuration: config, apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 512)
                let suffix: String
                switch format {
                case .openAIResponses: suffix = "/responses"
                case .openAIChatCompletions: suffix = "/chat/completions"
                case .anthropicMessages: suffix = "/messages"
                }
                var trimmed = base
                while trimmed.hasSuffix("/") { trimmed.removeLast() }
                XCTAssertEqual(stream.url?.absoluteString, trimmed + suffix)
                XCTAssertEqual(probe.url, stream.url)
                XCTAssertEqual(stream.value(forHTTPHeaderField: "Accept"), "text/event-stream")
                XCTAssertEqual(probe.value(forHTTPHeaderField: "Accept"), "application/json")
            }
        }
    }

    @MainActor
    func testRejectedGatewayURLsMakeZeroRequests() async {
        for base in ["http://gateway.invalid/v1", "https://user:pass@gateway.invalid/v1", "https://gateway.invalid/v1?key=fixture", "https://gateway.invalid/v1#fragment"] {
            for format in APIFormat.allCases {
                let transport = FixtureByteTransport(StreamingFixtures.success(format))
                do {
                    _ = try await StreamingService(transport: transport).stream(
                        configuration: APIConfiguration(apiFormat: format, baseURL: base, modelID: "fixture"),
                        apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in XCTFail("Unexpected text") }
                    XCTFail("Invalid URL must be rejected before transport")
                } catch { XCTAssertEqual(error as? StreamingError, .invalidRequest) }
                let count = await transport.requests.count
                XCTAssertEqual(count, 0)
            }
        }
    }

    func testChatCompletionIDCannotChangeMidStreamOrInUsage() throws {
        for choices in [true, false] {
            var decoder = ChatStreamDecoder()
            _ = try decoder.consume(chatEvent(id: "completion-a", text: "first"))
            XCTAssertThrowsError(try decoder.consume(chatEvent(id: "completion-b", text: "wrong", hasChoice: choices))) {
                XCTAssertEqual($0 as? StreamingError, .invalidEvent)
            }
        }
    }

    func testConsistentChatIDsAndAdditionalMetadataRemainCompatible() throws {
        var decoder = ChatStreamDecoder()
        XCTAssertEqual(try decoder.consume(chatEvent(id: "completion-a", text: "hello")).text, "hello")
        _ = try decoder.consume(chatEvent(id: "completion-a", text: "", finish: "stop"))
        _ = try decoder.consume(chatEvent(id: "completion-a", text: "", hasChoice: false))
        XCTAssertEqual(try decoder.consume(ServerSentEvent(name: "message", data: "[DONE]")).completion, .completed)
    }

    func testResponsesOutputIndexCannotChangeItemIdentity() throws {
        var decoder = ResponsesStreamDecoder()
        _ = try decoder.consume(event(["type": "response.created", "response": ["id": "r", "object": "response", "status": "in_progress"]]))
        _ = try decoder.consume(responseDelta(itemID: "item-a"))
        XCTAssertThrowsError(try decoder.consume(responseDelta(itemID: "item-b"))) {
            XCTAssertEqual($0 as? StreamingError, .invalidEvent)
        }
    }

    @MainActor
    func testUnknownAnthropicContentDeltaCannotReportCompleteSuccess() async throws {
        let body = StreamingFixtures.messagesStart + StreamingFixtures.blockStart(0)
            + StreamingFixtures.messagesDelta("known") + StreamingFixtures.messagesDelta("not-rendered", type: "future_content_delta")
            + StreamingFixtures.blockStop(0) + StreamingFixtures.messageReason("end_turn") + StreamingFixtures.messagesStop
        let (result, text, count) = try await stream(body, format: .anthropicMessages)
        XCTAssertEqual(result, .incomplete)
        XCTAssertEqual(text, "known")
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testAnthropicMultipleTextBlocksAndInitialTextAreNotDuplicated() async throws {
        let body = StreamingFixtures.messagesStart + StreamingFixtures.blockStart(0, text: "first")
            + StreamingFixtures.messagesDelta(" block") + StreamingFixtures.blockStop(0)
            + StreamingFixtures.blockStart(1, text: " second") + StreamingFixtures.messagesDelta(" block", index: 1)
            + StreamingFixtures.blockStop(1) + StreamingFixtures.messageReason("stop_sequence") + StreamingFixtures.messagesStop
        let (result, text, count) = try await stream(body, format: .anthropicMessages)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(text, "first block second block")
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testSSECommentsBOMAndCRLFWorkAcrossEveryProtocol() async throws {
        for format in APIFormat.allCases {
            let original = StreamingFixtures.success(format)
            let body = "\u{FEFF}: gateway heartbeat\r\n\r\n" + original.replacingOccurrences(of: "\n", with: "\r\n")
            let (result, text, count) = try await stream(body, format: format)
            XCTAssertEqual(result, .completed)
            XCTAssertEqual(text, StreamingFixtures.text)
            XCTAssertEqual(count, 1)
        }
    }

    private func event(_ object: [String: Any]) -> ServerSentEvent {
        ServerSentEvent(name: object["type"] as? String ?? "message", data: StreamingFixtures.json(object))
    }
    private func responseDelta(itemID: String) -> ServerSentEvent {
        event(["type": "response.output_text.delta", "output_index": 0, "content_index": 0, "item_id": itemID, "delta": "text"])
    }
    private func chatEvent(id: String, text: String, finish: String? = nil, hasChoice: Bool = true) -> ServerSentEvent {
        var choice: [String: Any] = ["index": 0, "delta": ["content": text]]
        if let finish { choice["finish_reason"] = finish }
        return event(["id": id, "object": "chat.completion.chunk", "choices": hasChoice ? [choice] : [], "gateway_metadata": ["ignored": true]])
    }
    @MainActor
    private func stream(_ body: String, format: APIFormat) async throws -> (StreamCompletion, String, Int) {
        let transport = FixtureByteTransport(body)
        let recorder = StreamTextRecorder()
        let result = try await StreamingService(transport: transport).stream(
            configuration: APIConfiguration(apiFormat: format, baseURL: "https://gateway.invalid/custom/v9", modelID: "fixture"),
            apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 512) { await recorder.append($0) }
        return (result, await recorder.text, await transport.requests.count)
    }
}
