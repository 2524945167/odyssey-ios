import XCTest
@testable import Odyssey

final class ConnectionTestProtocolTests: XCTestCase {
    private let fixtureKey = "odyssey-offline-fixture-not-a-credential"

    func testDefaultAndCustomOutputLimits() throws {
        XCTAssertEqual(ConnectionTestPolicy.defaultOutputLimit, 256)
        for (text, expected) in [("256", 256), ("1024", 1024), (" 4096\n", 4096), ("1", 1)] {
            XCTAssertEqual(try ConnectionTestPolicy.outputLimit(from: text), expected)
        }
    }

    func testInvalidOutputLimitsAreRejectedWithoutClamping() {
        for text in ["", " ", "0", "-1", "+256", "1.5", "1e3", "12 34", "abc", "２５６", String(repeating: "9", count: 100)] {
            XCTAssertThrowsError(try ConnectionTestPolicy.outputLimit(from: text)) {
                XCTAssertEqual($0 as? ConnectionTestError, .invalidOutputLimit)
            }
        }
    }

    func testThreeRequestFormatsUseExactCustomLimitAndOnlyProbeContent() throws {
        for format in APIFormat.allCases {
            let configuration = APIConfiguration(apiFormat: format, baseURL: "https://example.invalid/gateway/v1/", modelID: " custom-model ")
            let request = try APIProbeRequestBuilder.build(configuration: configuration, apiKey: fixtureKey, outputLimit: 1536)
            let data = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 30)
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(json["model"] as? String, "custom-model")
            XCTAssertEqual(json["stream"] as? Bool, false)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(fixtureKey))
            XCTAssertNil(json["temperature"])
            XCTAssertNil(json["tools"])
            XCTAssertNil(json["reasoning"])
            switch format {
            case .openAIResponses:
                XCTAssertEqual(request.url?.path, "/gateway/v1/responses")
                XCTAssertEqual(json["max_output_tokens"] as? Int, 1536)
                XCTAssertEqual(json["input"] as? String, "Reply with OK.")
                XCTAssertEqual(Set(json.keys), Set(["model", "input", "max_output_tokens", "stream", "store"]))
            case .openAIChatCompletions:
                XCTAssertEqual(request.url?.path, "/gateway/v1/chat/completions")
                XCTAssertEqual(json["max_completion_tokens"] as? Int, 1536)
                XCTAssertEqual(Set(json.keys), Set(["model", "messages", "max_completion_tokens", "stream", "store"]))
            case .anthropicMessages:
                XCTAssertEqual(request.url?.path, "/gateway/v1/messages")
                XCTAssertEqual(json["max_tokens"] as? Int, 1536)
                XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
                XCTAssertEqual(Set(json.keys), Set(["model", "messages", "max_tokens", "stream"]))
            }
            if format == .anthropicMessages {
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), fixtureKey)
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertNil(json["store"])
            } else {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + fixtureKey)
                XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
                XCTAssertNil(request.value(forHTTPHeaderField: "anthropic-version"))
                XCTAssertEqual(json["store"] as? Bool, false)
            }
            if format != .openAIResponses {
                let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
                XCTAssertEqual(messages, [["role": "user", "content": "Reply with OK."]])
            }
        }
    }

    func testEndpointPreservesCustomPathAndDoesNotGuessVersion() throws {
        let examples = [
            ("https://example.invalid", "https://example.invalid/responses"),
            ("https://example.invalid/v1///", "https://example.invalid/v1/responses"),
            ("https://example.invalid/my%20proxy/v2/", "https://example.invalid/my%20proxy/v2/responses")
        ]
        for (base, expected) in examples {
            XCTAssertEqual(try APIProbeRequestBuilder.endpoint(for: APIConfiguration(baseURL: base)).absoluteString, expected)
        }
    }

    func testUnsafeEndpointsAndKeysNeverBecomeRequests() {
        for base in ["http://example.invalid/v1", "https://user:pass@example.invalid", "https://example.invalid?secret=x", "https://example.invalid/#x", "https://"] {
            XCTAssertThrowsError(try APIProbeRequestBuilder.build(configuration: APIConfiguration(baseURL: base, modelID: "fixture"), apiKey: fixtureKey, outputLimit: 256))
        }
        for key in ["", " ", "fake\r\nInjected: header", "fake key", "fake\u{0}key", "非ASCII"] {
            XCTAssertThrowsError(try APIProbeRequestBuilder.build(configuration: APIConfiguration(modelID: "fixture"), apiKey: key, outputLimit: 256))
        }
        XCTAssertThrowsError(try APIProbeRequestBuilder.build(configuration: APIConfiguration(modelID: ""), apiKey: fixtureKey, outputLimit: 256))
        XCTAssertThrowsError(try APIProbeRequestBuilder.build(configuration: APIConfiguration(modelID: "fixture"), apiKey: fixtureKey, outputLimit: 0))
    }

    func testParsesTextResponsesForAllThreeProtocols() throws {
        for (format, json) in Self.successFixtures {
            XCTAssertEqual(try APIProbeResponseParser.parse(Data(json.utf8), format: format), .success)
        }
    }

    func testOutputExhaustionWithoutVisibleTextIsNotConnectionFailure() throws {
        let examples: [(APIFormat, String)] = [
            (.openAIResponses, #"{"object":"response","status":"incomplete","output":[],"incomplete_details":{"reason":"max_output_tokens"}}"#),
            (.openAIChatCompletions, #"{"object":"chat.completion","choices":[{"message":{"role":"assistant","content":null},"finish_reason":"length"}]}"#),
            (.anthropicMessages, #"{"type":"message","role":"assistant","content":[],"stop_reason":"max_tokens"}"#)
        ]
        for (format, json) in examples {
            XCTAssertEqual(try APIProbeResponseParser.parse(Data(json.utf8), format: format), .outputLimited)
        }
    }

    func testRefusalsAreNotReportedAsTextSuccess() throws {
        let examples: [(APIFormat, String)] = [
            (.openAIResponses, #"{"object":"response","status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"refusal","refusal":"declined"}]}]}"#),
            (.openAIChatCompletions, #"{"object":"chat.completion","choices":[{"message":{"role":"assistant","content":null,"refusal":"declined"},"finish_reason":"stop"}]}"#),
            (.anthropicMessages, #"{"type":"message","role":"assistant","content":[{"type":"text","text":"declined"}],"stop_reason":"end_turn","stop_details":{"type":"refusal"}}"#)
        ]
        for (format, json) in examples {
            XCTAssertEqual(try APIProbeResponseParser.parse(Data(json.utf8), format: format), .refused)
        }
    }

    func testEmptyCompletedResponseIsNotTextSuccess() throws {
        let examples: [(APIFormat, String)] = [
            (.openAIResponses, #"{"object":"response","status":"completed","output":[]}"#),
            (.openAIChatCompletions, #"{"object":"chat.completion","choices":[{"message":{"role":"assistant","content":" "},"finish_reason":"stop"}]}"#),
            (.anthropicMessages, #"{"type":"message","role":"assistant","content":[],"stop_reason":"end_turn"}"#)
        ]
        for (format, json) in examples {
            XCTAssertEqual(try APIProbeResponseParser.parse(Data(json.utf8), format: format), .noText)
        }
    }

    func testInvalidOrWrongProtocolResponsesAreRejected() {
        for format in APIFormat.allCases {
            for json in ["<html>proxy login</html>", "{}", #"{"error":{"message":"do not echo this"}}"#, #"{"ok":true}"#] {
                XCTAssertThrowsError(try APIProbeResponseParser.parse(Data(json.utf8), format: format)) {
                    XCTAssertEqual($0 as? ConnectionTestError, .invalidResponse)
                }
            }
            for (otherFormat, json) in Self.successFixtures where otherFormat != format {
                XCTAssertThrowsError(try APIProbeResponseParser.parse(Data(json.utf8), format: format))
            }
        }
    }

    func testResponsesFailureAndPendingDoNotStartPolling() {
        for json in [
            #"{"object":"response","status":"failed","output":[],"error":{"message":"private-error"}}"#,
            #"{"object":"response","status":"in_progress","output":[]}"#
        ] {
            XCTAssertThrowsError(try APIProbeResponseParser.parse(Data(json.utf8), format: .openAIResponses)) {
                XCTAssertEqual($0 as? ConnectionTestError, .generationFailed)
            }
        }
    }

    func testErrorMappingNeverReturnsUnderlyingPrivateDetails() {
        let sentinel = "fixture-private-url-and-key"
        let cases: [(URLError.Code, ConnectionTestError)] = [(.timedOut, .timedOut), (.cancelled, .cancelled), (.notConnectedToInternet, .offline), (.cannotFindHost, .unreachable), (.serverCertificateUntrusted, .tlsFailure), (.networkConnectionLost, .networkFailure)]
        for (code, expected) in cases {
            let safe = ConnectionTestError.sanitized(URLError(code, userInfo: [NSLocalizedDescriptionKey: sentinel]))
            XCTAssertEqual(safe, expected)
            XCTAssertFalse(safe.localizedDescription.contains(sentinel))
        }
        XCTAssertEqual(ConnectionTestError.sanitized(NSError(domain: sentinel, code: 5)), .networkFailure)
        for status in [301, 400, 401, 403, 404, 408, 422, 429, 500, 503, 504] {
            XCTAssertTrue(ConnectionTestError.http(status).localizedDescription.contains(String(status)))
        }
    }

    @MainActor
    func testServiceUsesOneRequestForSuccessAndDoesNotReturnResponseText() async throws {
        let transport = RecordingProbeTransport(payload: HTTPPayload(statusCode: 200, body: Data(Self.successFixtures[0].1.utf8)))
        let result = try await ConnectionTestService(transport: transport).test(configuration: APIConfiguration(modelID: "fixture"), apiKey: fixtureKey, outputLimit: 2048)
        XCTAssertEqual(result.outcome, .success)
        XCTAssertGreaterThanOrEqual(result.elapsedSeconds, 0)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func testHTTPFailuresNeverRetryOrSwitchProtocol() async {
        for code in [302, 400, 401, 403, 404, 429, 503] {
            let transport = RecordingProbeTransport(payload: HTTPPayload(statusCode: code, body: Data(fixtureKey.utf8)))
            do {
                _ = try await ConnectionTestService(transport: transport).test(configuration: APIConfiguration(modelID: "fixture"), apiKey: fixtureKey, outputLimit: 256)
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertEqual(error as? ConnectionTestError, .http(code))
                XCTAssertFalse(error.localizedDescription.contains(fixtureKey))
            }
            let count = await transport.requests.count
            XCTAssertEqual(count, 1)
        }
    }

    @MainActor
    func testTimeoutDoesNotRetry() async {
        let transport = RecordingProbeTransport(error: URLError(.timedOut))
        do {
            _ = try await ConnectionTestService(transport: transport).test(configuration: APIConfiguration(modelID: "fixture"), apiKey: fixtureKey, outputLimit: 256)
            XCTFail("Expected timeout")
        } catch { XCTAssertEqual(error as? ConnectionTestError, .timedOut) }
        let count = await transport.requests.count
        XCTAssertEqual(count, 1)
    }

    func testSessionConfigurationDisablesPersistentCachesAndCredentials() {
        let configuration = URLSessionHTTPTransport.secureConfiguration()
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertFalse(configuration.waitsForConnectivity)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 30)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 30)
    }

    func testRedirectDelegateRejectsCredentialForwarding() throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = try XCTUnwrap(URL(string: "https://source.invalid/responses"))
        let target = try XCTUnwrap(URL(string: "https://other.invalid/collect"))
        let response = try XCTUnwrap(HTTPURLResponse(url: source, statusCode: 302, httpVersion: nil, headerFields: nil))
        let task = session.dataTask(with: source) // 不 resume，不发出网络请求。
        let completion = expectation(description: "Redirect rejected")
        NoRedirectDelegate().urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: URLRequest(url: target)) { redirected in
            XCTAssertNil(redirected)
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
    }

    @MainActor
    func testRealURLSessionTransportWithOfflineURLProtocol() async throws {
        let transport = Self.offlineTransport()
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://offline.invalid/success")))
        let payload = try await transport.send(request)
        XCTAssertEqual(payload.statusCode, 200)
        XCTAssertEqual(String(decoding: payload.body, as: UTF8.self), "offline-fixture")
    }

    @MainActor
    func testTransportStopsOversizedResponseAndDiscardsFailureBody() async throws {
        let transport = Self.offlineTransport(limit: 4)
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://offline.invalid/success")))
        do {
            _ = try await transport.send(request)
            XCTFail("Expected response-size limit")
        } catch { XCTAssertEqual(error as? ConnectionTestError, .responseTooLarge) }
        let failure = try await transport.send(URLRequest(url: try XCTUnwrap(URL(string: "https://offline.invalid/failure"))))
        XCTAssertEqual(failure.statusCode, 401)
        XCTAssertTrue(failure.body.isEmpty)
    }

    private static func offlineTransport(limit: Int = 1024) -> URLSessionHTTPTransport {
        URLSessionHTTPTransport(maximumResponseBytes: limit) {
            let configuration = URLSessionHTTPTransport.secureConfiguration()
            configuration.protocolClasses = [OfflineProbeURLProtocol.self]
            return configuration
        }
    }

    private static let successFixtures: [(APIFormat, String)] = [
        (.openAIResponses, #"{"object":"response","status":"completed","error":null,"output":[{"type":"reasoning","summary":[]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"OK"}]}]}"#),
        (.openAIChatCompletions, #"{"object":"chat.completion","choices":[{"message":{"role":"assistant","content":"OK"},"finish_reason":"stop"}]}"#),
        (.anthropicMessages, #"{"type":"message","role":"assistant","content":[{"type":"text","text":"OK"}],"stop_reason":"end_turn"}"#)
    ]
}

private actor RecordingProbeTransport: HTTPTransport {
    private let payload: HTTPPayload
    private let error: URLError?
    private(set) var requests: [URLRequest] = []
    init(payload: HTTPPayload = HTTPPayload(statusCode: 200, body: Data()), error: URLError? = nil) {
        self.payload = payload
        self.error = error
    }
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        requests.append(request)
        if let error { throw error }
        return payload
    }
}

/// 测试用 URLProtocol 拦截所有请求，绝不访问 DNS 或外网。
private final class OfflineProbeURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: url.lastPathComponent == "failure" ? 401 : 200,
                                             httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("offline-fixture".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
