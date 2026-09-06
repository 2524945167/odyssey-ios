import XCTest
@testable import Odyssey

final class StreamingServiceTests: XCTestCase {
    func testRequestFieldWhitelistsAndExplicitBudgetForAllProtocols() throws {
        for format in APIFormat.allCases {
            let configuration = APIConfiguration(apiFormat: format, baseURL: "https://example.invalid/proxy%20path/v9///", modelID: "fixture-model")
            let request = try StreamingRequestBuilder.build(configuration: configuration, apiKey: StreamingFixtures.key,
                                                            input: StreamingFixtures.text, outputLimit: 1536)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertTrue(try XCTUnwrap(request.url?.absoluteString).contains("/proxy%20path/v9/"))
            XCTAssertEqual(request.timeoutInterval, 30)
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertEqual(json["stream"] as? Bool, true)
            let keys: Set<String>
            switch format {
            case .openAIResponses:
                keys = ["model", "input", "max_output_tokens", "stream", "store"]
                XCTAssertEqual(json["input"] as? String, StreamingFixtures.text)
                XCTAssertEqual(json["max_output_tokens"] as? Int, 1536)
                XCTAssertTrue(request.url!.path.hasSuffix("/responses"))
            case .openAIChatCompletions:
                keys = ["model", "messages", "max_completion_tokens", "stream", "store"]
                XCTAssertEqual(json["max_completion_tokens"] as? Int, 1536)
                XCTAssertTrue(request.url!.path.hasSuffix("/chat/completions"))
            case .anthropicMessages:
                keys = ["model", "messages", "max_tokens", "stream"]
                XCTAssertEqual(json["max_tokens"] as? Int, 1536)
                XCTAssertTrue(request.url!.path.hasSuffix("/messages"))
            }
            XCTAssertEqual(Set(json.keys), keys)
            if format == .anthropicMessages {
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), StreamingFixtures.key)
                XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            } else {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + StreamingFixtures.key)
                XCTAssertEqual(json["store"] as? Bool, false)
                XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
                XCTAssertNil(request.value(forHTTPHeaderField: "anthropic-version"))
            }
            if format != .openAIResponses {
                XCTAssertEqual(json["messages"] as? [[String: String]], [["role": "user", "content": StreamingFixtures.text]])
            }
        }
        XCTAssertEqual(ConnectionTestPolicy.defaultOutputLimit, 256)
        let probe = try APIProbeRequestBuilder.build(configuration: APIConfiguration(modelID: "fixture"), apiKey: StreamingFixtures.key, outputLimit: 256)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(probe.httpBody)) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["input"] as? String, "Reply with OK.")
    }

    @MainActor
    func testThreeProtocolsJoinUTF8PiecesWithoutDuplicatingSnapshots() async throws {
        for format in APIFormat.allCases {
            for size in [1, 7, 4096] {
                let result = try await run(StreamingFixtures.success(format), format: format, chunkSize: size)
                XCTAssertEqual(result.0, .completed)
                XCTAssertEqual(result.1, StreamingFixtures.text)
            }
        }
    }

    @MainActor
    func testPartialTextWithoutTerminalIsNeverSuccess() async {
        for format in APIFormat.allCases {
            await expectFailure(StreamingFixtures.partial(format), format: format, error: .unexpectedEnd,
                                partial: StreamingFixtures.text)
        }
        await expectFailure(StreamingFixtures.partial(.openAIChatCompletions) + StreamingFixtures.chat(finish: "stop"),
                            format: .openAIChatCompletions, error: .unexpectedEnd, partial: StreamingFixtures.text)
    }

    @MainActor
    func testEOFDoesNotCompleteUnterminatedTerminalFrame() async {
        for format in APIFormat.allCases {
            let stream = String(StreamingFixtures.success(format).dropLast())
            await expectFailure(stream, format: format, error: .unexpectedEnd, partial: StreamingFixtures.text)
        }
    }

    @MainActor
    func testOutputLimitsAndRefusalsAreDistinctFromSuccess() async throws {
        let fixtures: [(APIFormat, String, StreamCompletion)] = [
            (.openAIResponses, StreamingFixtures.partial(.openAIResponses) + StreamingFixtures.responsesEnd(reason: "max_output_tokens"), .outputLimited),
            (.openAIResponses, StreamingFixtures.partial(.openAIResponses) + StreamingFixtures.responsesEnd(refusal: true), .refused),
            (.openAIChatCompletions, StreamingFixtures.partial(.openAIChatCompletions) + StreamingFixtures.chat(finish: "length") + StreamingFixtures.done, .outputLimited),
            (.openAIChatCompletions, StreamingFixtures.chat(refusal: "fixture-refusal") + StreamingFixtures.chat(finish: "stop") + StreamingFixtures.done, .refused),
            (.anthropicMessages, StreamingFixtures.partial(.anthropicMessages) + StreamingFixtures.messageReason("max_tokens") + StreamingFixtures.messagesStop, .outputLimited),
            (.anthropicMessages, StreamingFixtures.partial(.anthropicMessages) + StreamingFixtures.messageReason("end_turn", refusal: true) + StreamingFixtures.messagesStop, .refused)
        ]
        for (format, body, expected) in fixtures { let result = try await run(body, format: format); XCTAssertEqual(result.0, expected) }
    }

    @MainActor
    func testEmptyGenerationAndUnknownStopReason() async throws {
        let empty: [(APIFormat, String)] = [
            (.openAIResponses, StreamingFixtures.responsesStart + StreamingFixtures.responsesEnd("")),
            (.openAIChatCompletions, StreamingFixtures.chat(finish: "stop") + StreamingFixtures.done),
            (.anthropicMessages, StreamingFixtures.messagesStart + StreamingFixtures.messageReason("end_turn") + StreamingFixtures.messagesStop)
        ]
        for (format, body) in empty { let result = try await run(body, format: format); XCTAssertEqual(result.0, .noText) }
        let result = try await run(StreamingFixtures.chat("partial", finish: "future_reason") + StreamingFixtures.done, format: .openAIChatCompletions)
        XCTAssertEqual(result.0, .incomplete)
    }

    @MainActor
    func testReasoningAndUnknownEventsNeverBecomeVisibleText() async throws {
        let hidden = "fixture-hidden-reasoning"
        let responses = StreamingFixtures.responsesStart
            + StreamingFixtures.event(["type": "response.reasoning_text.delta", "delta": hidden])
            + StreamingFixtures.event(["type": "response.future_event", "delta": ["nested": hidden]])
            + StreamingFixtures.responsesDelta("OK") + StreamingFixtures.responsesEnd("OK")
        let r = try await run(responses, format: .openAIResponses)
        XCTAssertEqual(r.1, "OK")
        let messages = StreamingFixtures.messagesStart + StreamingFixtures.blockStart(0, kind: "thinking")
            + StreamingFixtures.messagesDelta(hidden, type: "thinking_delta") + StreamingFixtures.blockStop(0)
            + StreamingFixtures.event(["type": "future_event", "extra": hidden])
            + StreamingFixtures.event(["type": "ping"])
            + StreamingFixtures.blockStart(1, text: "O") + StreamingFixtures.messagesDelta("K", index: 1)
            + StreamingFixtures.blockStop(1) + StreamingFixtures.messageReason("end_turn") + StreamingFixtures.messagesStop
        let m = try await run(messages, format: .anthropicMessages)
        XCTAssertEqual(m.0, .completed); XCTAssertEqual(m.1, "OK")
    }

    @MainActor
    func testInStreamErrorsAreRedactedAndNeverRetried() async {
        for format in APIFormat.allCases {
            let errorBody: String = format == .openAIChatCompletions
                ? StreamingFixtures.event(["error": ["message": StreamingFixtures.key]], named: false)
                : StreamingFixtures.event(["type": "error", "error": ["message": StreamingFixtures.key]])
            await expectFailure(StreamingFixtures.partial(format) + errorBody, format: format,
                                error: .generationFailed, partial: StreamingFixtures.text)
        }
    }

    @MainActor
    func testWrongProtocolAndMalformedJSONAreRejected() async {
        for format in APIFormat.allCases {
            for other in APIFormat.allCases where other != format {
                await expectFailure(StreamingFixtures.success(other), format: format, error: .invalidEvent)
            }
            await expectFailure("data: {invalid-json}\n\n", format: format, error: .invalidEvent)
        }
    }

    @MainActor
    func testResponsesSnapshotMismatchAndSequenceReplayFail() async {
        await expectFailure(StreamingFixtures.responsesStart + StreamingFixtures.responsesDelta("A") + StreamingFixtures.responsesEnd("B"),
                            format: .openAIResponses, error: .invalidEvent, partial: "A")
        await expectFailure(StreamingFixtures.responsesStart + StreamingFixtures.responsesDelta("A", sequence: 1)
                            + StreamingFixtures.responsesDelta("B", sequence: 1), format: .openAIResponses, error: .invalidEvent, partial: "A")
        await expectFailure(StreamingFixtures.responsesEnd(""), format: .openAIResponses, error: .invalidEvent)
    }

    @MainActor
    func testMessagesRejectUnknownIndexDuplicateBlockAndEarlyStop() async {
        let start = StreamingFixtures.messagesStart
        for body in [start + StreamingFixtures.messagesDelta("bad"),
                     start + StreamingFixtures.blockStart(0) + StreamingFixtures.blockStart(0),
                     start + StreamingFixtures.blockStart(0, kind: "thinking") + StreamingFixtures.messagesDelta("bad"),
                     start + StreamingFixtures.blockStart(0) + StreamingFixtures.messageReason("end_turn")] {
            await expectFailure(body, format: .anthropicMessages, error: .invalidEvent)
        }
        await expectFailure(start + StreamingFixtures.messagesStop, format: .anthropicMessages, error: .unexpectedEnd)
    }

    @MainActor
    func testChatRequiresFinishReasonAndDoesNotExecuteTools() async throws {
        await expectFailure(StreamingFixtures.done, format: .openAIChatCompletions, error: .unexpectedEnd)
        await expectFailure(StreamingFixtures.chat(finish: "stop") + StreamingFixtures.chat("late"), format: .openAIChatCompletions, error: .invalidEvent)
        let tool = StreamingFixtures.event(["object": "chat.completion.chunk", "choices": [["index": 0, "delta": ["tool_calls": [["id": "fixture-tool"]]], "finish_reason": "tool_calls"]]], named: false)
        let result = try await run(tool + StreamingFixtures.done, format: .openAIChatCompletions)
        XCTAssertEqual(result.0, .incomplete); XCTAssertEqual(result.1, "")
    }

    @MainActor
    func testMatchingTerminalStopsReadingEvenIfConnectionStaysOpen() async throws {
        for format in APIFormat.allCases {
            let transport = FixtureByteTransport(StreamingFixtures.success(format), failure: URLError(.timedOut))
            let result = try await StreamingService(transport: transport).stream(configuration: config(format), apiKey: StreamingFixtures.key,
                                                                                input: "fixture", outputLimit: 1024) { _ in }
            XCTAssertEqual(result, .completed)
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    @MainActor
    func testInvalidRequestsNeverReachTransport() async {
        let bad: [(APIConfiguration, String, String, Int)] = [
            (APIConfiguration(modelID: ""), StreamingFixtures.key, "text", 256),
            (APIConfiguration(baseURL: "http://offline.invalid", modelID: "fixture"), StreamingFixtures.key, "text", 256),
            (config(.openAIResponses), "bad\r\nInjected: header", "text", 256),
            (config(.openAIResponses), StreamingFixtures.key, " \n\t", 256),
            (config(.openAIResponses), StreamingFixtures.key, "text", 0)
        ]
        for (configuration, key, input, limit) in bad {
            let transport = FixtureByteTransport("")
            do {
                _ = try await StreamingService(transport: transport).stream(configuration: configuration, apiKey: key, input: input, outputLimit: limit) { _ in XCTFail("Unexpected callback") }
                XCTFail("Expected rejection")
            } catch { XCTAssertEqual(error as? StreamingError, .invalidRequest) }
            let requests = await transport.requests
            XCTAssertTrue(requests.isEmpty)
        }
    }

    @MainActor
    func testPreCancelledTaskNeverSendsRequest() async {
        let transport = FixtureByteTransport(StreamingFixtures.success(.openAIResponses))
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await StreamingService(transport: transport).stream(configuration: self.config(.openAIResponses), apiKey: StreamingFixtures.key,
                                                                           input: "fixture", outputLimit: 256) { _ in XCTFail("Unexpected callback") }
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? StreamingError, .cancelled) }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    @MainActor
    func testTimeoutAndNetworkFailuresRetainPartialTextWithoutRetry() async {
        for (code, expected) in [(URLError.Code.timedOut, StreamingError.timedOut), (.networkConnectionLost, .networkFailure)] {
            let transport = FixtureByteTransport(StreamingFixtures.partial(.openAIResponses), failure: URLError(code, userInfo: [NSLocalizedDescriptionKey: StreamingFixtures.key]))
            let recorder = StreamTextRecorder()
            do {
                _ = try await StreamingService(transport: transport).stream(configuration: config(.openAIResponses), apiKey: StreamingFixtures.key,
                                                                           input: "fixture", outputLimit: 256) { await recorder.append($0) }
                XCTFail("Expected failure")
            } catch {
                XCTAssertEqual(error as? StreamingError, expected)
                XCTAssertFalse(error.localizedDescription.contains(StreamingFixtures.key))
            }
            let text = await recorder.text; let count = await transport.requests.count
            XCTAssertEqual(text, StreamingFixtures.text); XCTAssertEqual(count, 1)
        }
    }

    @MainActor
    private func run(_ content: String, format: APIFormat, chunkSize: Int = 1) async throws -> (StreamCompletion, String) {
        let transport = FixtureByteTransport(content, chunkSize: chunkSize)
        let recorder = StreamTextRecorder()
        let result = try await StreamingService(transport: transport).stream(configuration: config(format), apiKey: StreamingFixtures.key,
                                                                            input: "fixture", outputLimit: 1024) { await recorder.append($0) }
        return (result, await recorder.text)
    }

    @MainActor
    private func expectFailure(_ content: String, format: APIFormat, error expected: StreamingError, partial: String = "",
                               file: StaticString = #filePath, line: UInt = #line) async {
        let transport = FixtureByteTransport(content)
        let recorder = StreamTextRecorder()
        do {
            _ = try await StreamingService(transport: transport).stream(configuration: config(format), apiKey: StreamingFixtures.key,
                                                                       input: "fixture", outputLimit: 1024) { await recorder.append($0) }
            XCTFail("Expected failure", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? StreamingError, expected, file: file, line: line)
            XCTAssertFalse(error.localizedDescription.contains(StreamingFixtures.key), file: file, line: line)
        }
        let text = await recorder.text; let count = await transport.requests.count
        XCTAssertEqual(text, partial, file: file, line: line); XCTAssertEqual(count, 1, file: file, line: line)
    }

    private func config(_ format: APIFormat) -> APIConfiguration {
        APIConfiguration(apiFormat: format, baseURL: "https://offline.invalid/v1", modelID: "fixture-model")
    }
}
