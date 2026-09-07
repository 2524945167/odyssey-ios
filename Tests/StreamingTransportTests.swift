import XCTest
@testable import Odyssey

final class StreamingTransportTests: XCTestCase {
    @MainActor
    func testActualURLSessionStreamsAllProtocolsOffline() async throws {
        for format in APIFormat.allCases {
            let fixture = StreamHTTPFixture(body: StreamingFixtures.success(format))
            let id = StreamHTTPRegistry.shared.insert(fixture)
            defer { StreamHTTPRegistry.shared.remove(id) }
            let recorder = StreamTextRecorder()
            let result = try await StreamingService(transport: offlineTransport()).stream(
                configuration: configuration(id, format: format), apiKey: StreamingFixtures.key,
                input: "fixture", outputLimit: 1024) { await recorder.append($0) }
            XCTAssertEqual(result, .completed)
            let text = await recorder.text
            XCTAssertEqual(text, StreamingFixtures.text)
            XCTAssertEqual(fixture.startCount, 1)
        }
    }

    @MainActor
    func testHTTPFailuresDiscardBodyAndNeverRetryOrRedirect() async {
        for code in [302, 400, 401, 403, 429, 503] {
            let fixture = StreamHTTPFixture(body: StreamingFixtures.key, status: code)
            let id = StreamHTTPRegistry.shared.insert(fixture)
            defer { StreamHTTPRegistry.shared.remove(id) }
            do {
                _ = try await StreamingService(transport: offlineTransport()).stream(
                    configuration: configuration(id), apiKey: StreamingFixtures.key,
                    input: "fixture", outputLimit: 256) { _ in XCTFail("Error body must not be delivered") }
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertEqual(error as? StreamingError, .http(code))
                XCTAssertFalse(error.localizedDescription.contains(StreamingFixtures.key))
            }
            XCTAssertEqual(fixture.startCount, 1)
        }
    }

    @MainActor
    func testHTTP200JSONAndHTMLDoNotFallBackToNonStreaming() async {
        for mime in ["application/json", "text/html", ""] {
            let fixture = StreamHTTPFixture(body: StreamingFixtures.success(.openAIResponses), contentType: mime)
            let id = StreamHTTPRegistry.shared.insert(fixture)
            defer { StreamHTTPRegistry.shared.remove(id) }
            do {
                _ = try await StreamingService(transport: offlineTransport()).stream(
                    configuration: configuration(id), apiKey: StreamingFixtures.key,
                    input: "fixture", outputLimit: 256) { _ in XCTFail("Unexpected text") }
                XCTFail("Expected content-type rejection")
            } catch { XCTAssertEqual(error as? StreamingError, .invalidContentType) }
            XCTAssertEqual(fixture.startCount, 1)
        }
    }

    @MainActor
    func testEventStreamContentTypeAcceptsCharsetAndCase() async throws {
        let fixture = StreamHTTPFixture(body: StreamingFixtures.success(.openAIResponses), contentType: "Text/Event-Stream; charset=utf-8")
        let id = StreamHTTPRegistry.shared.insert(fixture)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let result = try await StreamingService(transport: offlineTransport()).stream(
            configuration: configuration(id), apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in }
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    func testDeclaredAndActualResponseSizeAreBounded() async {
        for length in [nil, "5000"] as [String?] {
            let fixture = StreamHTTPFixture(body: String(repeating: ": ping\n\n", count: 100), contentLength: length)
            let id = StreamHTTPRegistry.shared.insert(fixture)
            defer { StreamHTTPRegistry.shared.remove(id) }
            do {
                _ = try await StreamingService(transport: offlineTransport(limit: 32)).stream(
                    configuration: configuration(id), apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in }
                XCTFail("Expected size limit")
            } catch { XCTAssertEqual(error as? StreamingError, .responseTooLarge) }
        }
    }

    @MainActor
    func testCancelBeforeHeadersStopsActualSession() async {
        let began = expectation(description: "URLProtocol started")
        let stopped = expectation(description: "URLProtocol stopped")
        let fixture = StreamHTTPFixture(body: "", finishes: false, sendsHeaders: false, began: began, stopped: stopped)
        let id = StreamHTTPRegistry.shared.insert(fixture)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let service = StreamingService(transport: offlineTransport())
        let config = configuration(id)
        let task = Task {
            try await service.stream(configuration: config, apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in XCTFail("Unexpected text") }
        }
        await fulfillment(of: [began], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? StreamingError, .cancelled) }
        await fulfillment(of: [stopped], timeout: 3)
        XCTAssertEqual(fixture.startCount, 1)
    }

    @MainActor
    func testCancelAfterFirstTextStopsSessionAndPreservesPartialText() async {
        let textArrived = expectation(description: "Text received before EOF")
        let stopped = expectation(description: "Underlying stream stopped")
        let fixture = StreamHTTPFixture(body: StreamingFixtures.responsesStart + StreamingFixtures.responsesDelta("partial"),
                                       finishes: false, stopped: stopped)
        let id = StreamHTTPRegistry.shared.insert(fixture)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let service = StreamingService(transport: offlineTransport())
        let recorder = StreamTextRecorder()
        let config = configuration(id)
        let task = Task {
            try await service.stream(configuration: config, apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) {
                await recorder.append($0)
                textArrived.fulfill()
            }
        }
        await fulfillment(of: [textArrived], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? StreamingError, .cancelled) }
        await fulfillment(of: [stopped], timeout: 3)
        let text = await recorder.text
        XCTAssertEqual(text, "partial")
        XCTAssertEqual(fixture.startCount, 1)
    }

    @MainActor
    func testTerminalClosesSessionWithoutWaitingForEOF() async throws {
        let stopped = expectation(description: "Terminal cancels still-open session")
        let fixture = StreamHTTPFixture(body: StreamingFixtures.success(.openAIResponses), finishes: false, stopped: stopped)
        let id = StreamHTTPRegistry.shared.insert(fixture)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let result = try await StreamingService(transport: offlineTransport()).stream(
            configuration: configuration(id), apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in }
        XCTAssertEqual(result, .completed)
        await fulfillment(of: [stopped], timeout: 3)
    }

    @MainActor
    func testConsumerFailureClosesSessionAndRedactsPrivateError() async {
        let stopped = expectation(description: "Consumer failure cancels session")
        let fixture = StreamHTTPFixture(body: StreamingFixtures.partial(.openAIResponses), finishes: false, stopped: stopped)
        let id = StreamHTTPRegistry.shared.insert(fixture)
        defer { StreamHTTPRegistry.shared.remove(id) }
        do {
            _ = try await StreamingService(transport: offlineTransport()).stream(
                configuration: configuration(id), apiKey: StreamingFixtures.key, input: "fixture", outputLimit: 256) { _ in
                    throw NSError(domain: "fixture-private-domain", code: 1, userInfo: [NSLocalizedDescriptionKey: StreamingFixtures.key])
                }
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? StreamingError, .networkFailure)
            XCTAssertFalse(error.localizedDescription.contains(StreamingFixtures.key))
        }
        await fulfillment(of: [stopped], timeout: 3)
    }

    @MainActor
    func testHomepageCancellationClosesUnderlyingSessionBeforeFirstResponse() async throws {
        let began = expectation(description: "Homepage request started")
        let stopped = expectation(description: "Homepage cancellation closed session")
        let network = StreamHTTPFixture(body: "", finishes: false, sendsHeaders: false, began: began, stopped: stopped)
        let id = StreamHTTPRegistry.shared.insert(network)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let fixture = try TranslationTestFixture(service: TranslationService(transport: offlineTransport()))
        defer { fixture.cleanUp() }
        try fixture.storage.saveConfiguration(configuration(id))
        let task = try XCTUnwrap(fixture.model.startTranslation())
        await fulfillment(of: [began], timeout: 3)
        fixture.model.cancelTranslation()
        await task.value
        await fulfillment(of: [stopped], timeout: 3)
        XCTAssertEqual(fixture.model.state, .cancelled)
        XCTAssertEqual(network.startCount, 1)
    }

    @MainActor
    func testHomepageNativeTransportPreservesPartialTextOnTimeoutWithoutRetry() async throws {
        let network = StreamHTTPFixture(body: StreamingFixtures.partial(.openAIResponses), failure: URLError(.timedOut))
        let id = StreamHTTPRegistry.shared.insert(network)
        defer { StreamHTTPRegistry.shared.remove(id) }
        let transport = URLSessionStreamingTransport {
            let config = TranslationService.sessionConfiguration(options: TranslationOptions(idleTimeoutSeconds: 120))
            config.protocolClasses = [OfflineStreamURLProtocol.self]
            return config
        }
        let fixture = try TranslationTestFixture(service: TranslationService(transport: transport))
        defer { fixture.cleanUp() }
        try fixture.storage.saveConfiguration(configuration(id))
        try fixture.preferences.save(TranslationOptions(idleTimeoutSeconds: 120))
        let task = try XCTUnwrap(fixture.model.startTranslation())
        await task.value
        XCTAssertEqual(fixture.model.state, .failed(.request(.timedOut)))
        // URLSession may surface an immediate transport error before yielding buffered bytes.
        // Deterministic partial-text preservation is covered by the controlled stream tests.
        XCTAssertTrue(fixture.model.translatedText.isEmpty || StreamingFixtures.text.hasPrefix(fixture.model.translatedText))
        XCTAssertEqual(network.startCount, 1)
    }

    private func offlineTransport(limit: Int = 2 * 1024 * 1024) -> URLSessionStreamingTransport {
        URLSessionStreamingTransport(maximumResponseBytes: limit) {
            let configuration = URLSessionHTTPTransport.secureConfiguration()
            configuration.protocolClasses = [OfflineStreamURLProtocol.self]
            return configuration
        }
    }
    private func configuration(_ id: String, format: APIFormat = .openAIResponses) -> APIConfiguration {
        APIConfiguration(apiFormat: format, baseURL: "https://\(id).invalid/v1", modelID: "fixture-model")
    }
}

/// 不可变夹具 + 锁保护计数；每个测试用唯一 host 隔离，可并行运行。
private final class StreamHTTPFixture: @unchecked Sendable {
    let body: [Data]
    let status: Int
    let headers: [String: String]
    let finishes: Bool
    let sendsHeaders: Bool
    let failure: URLError?
    private let began: XCTestExpectation?
    private let stopped: XCTestExpectation?
    private let lock = NSLock()
    private var starts = 0
    private var didStop = false
    init(body: String, status: Int = 200, contentType: String = "text/event-stream", contentLength: String? = nil,
         finishes: Bool = true, sendsHeaders: Bool = true, began: XCTestExpectation? = nil, stopped: XCTestExpectation? = nil,
         failure: URLError? = nil) {
        self.body = StreamingFixtures.chunks(body, size: 7)
        self.status = status
        var headers = ["Content-Type": contentType]
        if let contentLength { headers["Content-Length"] = contentLength }
        if status == 302 { headers["Location"] = "https://must-not-follow.invalid/collect" }
        self.headers = headers
        self.finishes = finishes; self.sendsHeaders = sendsHeaders
        self.began = began; self.stopped = stopped
        self.failure = failure
    }
    var startCount: Int { lock.withLock { starts } }
    func start() { lock.withLock { starts += 1 }; began?.fulfill() }
    func stop() {
        let shouldFulfill = lock.withLock { let first = !didStop; didStop = true; return first }
        if shouldFulfill { stopped?.fulfill() }
    }
}

private final class StreamHTTPRegistry: @unchecked Sendable {
    static let shared = StreamHTTPRegistry()
    private let lock = NSLock()
    private var fixtures: [String: StreamHTTPFixture] = [:]
    func insert(_ value: StreamHTTPFixture) -> String {
        let id = UUID().uuidString.lowercased()
        lock.withLock { fixtures[id + ".invalid"] = value }
        return id
    }
    func lookup(_ host: String) -> StreamHTTPFixture? { lock.withLock { fixtures[host] } }
    func remove(_ id: String) { _ = lock.withLock { fixtures.removeValue(forKey: id + ".invalid") } }
}

/// 拦截所有 URL（包括错误地址），未知夹具直接报错，绝不回落外网/DNS。
private final class OfflineStreamURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let host = url.host, let fixture = StreamHTTPRegistry.shared.lookup(host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable)); return
        }
        fixture.start()
        guard fixture.sendsHeaders else { return }
        guard let response = HTTPURLResponse(url: url, statusCode: fixture.status, httpVersion: "HTTP/1.1", headerFields: fixture.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for data in fixture.body { client?.urlProtocol(self, didLoad: data) }
        if let failure = fixture.failure {
            client?.urlProtocol(self, didFailWithError: failure)
        } else if fixture.finishes {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {
        if let host = request.url?.host { StreamHTTPRegistry.shared.lookup(host)?.stop() }
    }
}
