import Foundation

public protocol ConnectionTesting: Sendable {
    func test(configuration: APIConfiguration, apiKey: String, outputLimit: Int) async throws -> ConnectionTestResult
}

public struct ConnectionTestService: ConnectionTesting {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionHTTPTransport()) {
        self.transport = transport
    }

    public func test(configuration: APIConfiguration, apiKey: String, outputLimit: Int) async throws -> ConnectionTestResult {
        do {
            try Task.checkCancellation()
            let request = try APIProbeRequestBuilder.build(configuration: configuration, apiKey: apiKey, outputLimit: outputLimit)
            let clock = ContinuousClock()
            let start = clock.now
            let payload = try await transport.send(request)
            try Task.checkCancellation()
            guard (200..<300).contains(payload.statusCode) else { throw ConnectionTestError.http(payload.statusCode) }
            let outcome = try APIProbeResponseParser.parse(payload.body, format: configuration.apiFormat)
            let duration = (clock.now - start).components
            return ConnectionTestResult(outcome: outcome, elapsedSeconds: Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
        } catch {
            throw ConnectionTestError.sanitized(error)
        }
    }
}
