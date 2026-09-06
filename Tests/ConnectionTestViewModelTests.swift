import XCTest
import SwiftUI
@testable import Odyssey

final class ConnectionTestViewModelTests: XCTestCase {
    @MainActor
    func testPreferencesDefaultCustomValueAndInvalidValuePreservesPrevious() throws {
        let fixture = try ProbeViewModelFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.preferences.outputLimit, 256)
        try fixture.preferences.saveOutputLimit(4096)
        XCTAssertEqual(ConnectionTestPreferences(defaults: fixture.defaults).outputLimit, 4096)
        XCTAssertThrowsError(try fixture.preferences.saveOutputLimit(0))
        XCTAssertEqual(fixture.preferences.outputLimit, 4096)
        let domain = try XCTUnwrap(fixture.defaults.persistentDomain(forName: fixture.suiteName))
        XCTAssertEqual(Set(domain.keys), [ConnectionTestPreferences.outputLimitKey])
        XCTAssertEqual(domain[ConnectionTestPreferences.outputLimitKey] as? Int, 4096)
    }

    @MainActor
    func testViewInitializationAndEditingDoNotSendRequests() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        fixture.model.refreshConfiguration()
        fixture.model.outputLimitText = "1024"
        fixture.model.resetOutputLimit()
        XCTAssertEqual(fixture.model.outputLimitText, "256")
        XCTAssertEqual(fixture.model.state, .idle)
        let count = await service.calls.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(fixture.defaults.persistentDomain(forName: fixture.suiteName)?[ConnectionTestPreferences.outputLimitKey])
    }

    @MainActor
    func testCustomLimitPersistsAndReachesServiceWithoutChangingAPIConfigurationOrKey() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let before = fixture.storage.loadConfiguration()
        fixture.model.outputLimitText = "2048"
        let task = try XCTUnwrap(fixture.model.start())
        XCTAssertEqual(fixture.model.state, .running)
        try await awaitCalls(service, count: 1)
        let calls = await service.calls
        XCTAssertEqual(calls.first?.outputLimit, 2048)
        XCTAssertEqual(calls.first?.configuration, before)
        XCTAssertEqual(calls.first?.apiKey, ProbeViewModelFixture.fakeKey)
        await service.complete(0, outcome: .success)
        await task.value
        XCTAssertEqual(fixture.model.state, .finished(ConnectionTestResult(outcome: .success, elapsedSeconds: 0.1)))
        let reopened = ConnectionTestViewModel(store: fixture.store, service: service, preferences: fixture.preferences)
        XCTAssertEqual(reopened.outputLimitText, "2048")
        XCTAssertEqual(fixture.storage.loadConfiguration(), before)
        XCTAssertEqual(try fixture.keychain.readAPIKey(), ProbeViewModelFixture.fakeKey)
        XCTAssertEqual(fixture.keychain.addCallCount, 1)
        XCTAssertEqual(fixture.keychain.updateCallCount, 0)
        XCTAssertEqual(fixture.keychain.deleteCallCount, 0)
        XCTAssertEqual(Set(fixture.defaults.persistentDomain(forName: fixture.suiteName)?.keys.map { $0 } ?? []), [ConnectionTestPreferences.outputLimitKey])
    }

    @MainActor
    func testInvalidLimitNeverSendsAndEditingClearsError() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        for invalid in ["", "0", "-10", "2.5", "abc", String(repeating: "9", count: 100)] {
            fixture.model.outputLimitText = invalid
            XCTAssertNil(fixture.model.start())
            XCTAssertEqual(fixture.model.state, .failed(.invalidOutputLimit))
            XCTAssertNotNil(fixture.model.outputLimitError)
        }
        fixture.model.outputLimitText = "512"
        XCTAssertNil(fixture.model.outputLimitError)
        XCTAssertEqual(fixture.model.state, .idle)
        XCTAssertEqual(fixture.preferences.outputLimit, 256)
        let count = await service.calls.count
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testMissingConfigurationOrKeyNeverSends() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        try fixture.keychain.deleteAPIKey()
        fixture.model.refreshConfiguration()
        XCTAssertFalse(fixture.model.canStart)
        XCTAssertNil(fixture.model.start())
        XCTAssertEqual(fixture.model.state, .failed(.notConfigured))
        try fixture.keychain.saveAPIKey(ProbeViewModelFixture.fakeKey)
        fixture.storage.clearConfiguration()
        XCTAssertNil(fixture.model.start())
        XCTAssertEqual(fixture.model.state, .failed(.notConfigured))
        let count = await service.calls.count
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testLatestSavedConfigurationIsUsedInsteadOfStalePageSnapshot() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let updated = APIConfiguration(apiFormat: .anthropicMessages, baseURL: "https://example.invalid/new/v1", modelID: "new-model")
        try fixture.storage.saveConfiguration(updated)
        let task = try XCTUnwrap(fixture.model.start())
        try await awaitCalls(service, count: 1)
        let configuration = await service.calls.first?.configuration
        XCTAssertEqual(configuration, updated)
        XCTAssertEqual(fixture.model.endpointText, "https://example.invalid/new/v1/messages")
        await service.complete(0, outcome: .success)
        await task.value
    }

    @MainActor
    func testDuplicateStartCreatesOnlyOneRequest() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let task = try XCTUnwrap(fixture.model.start())
        XCTAssertNil(fixture.model.start())
        XCTAssertFalse(fixture.model.canStart)
        fixture.model.resetOutputLimit()
        try await awaitCalls(service, count: 1)
        let count = await service.calls.count
        XCTAssertEqual(count, 1)
        await service.complete(0, outcome: .success)
        await task.value
        XCTAssertTrue(fixture.model.canStart)
    }

    @MainActor
    func testCancelBeforeTaskStartsSendsNothing() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let task = try XCTUnwrap(fixture.model.start())
        fixture.model.cancel()
        await task.value
        XCTAssertEqual(fixture.model.state, .cancelled)
        let count = await service.calls.count
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testCancelledOldResponseCannotOverwriteNewResult() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let old = try XCTUnwrap(fixture.model.start())
        try await awaitCalls(service, count: 1)
        fixture.model.cancel()
        XCTAssertEqual(fixture.model.state, .cancelled)
        fixture.model.outputLimitText = "512"
        let new = try XCTUnwrap(fixture.model.start())
        try await awaitCalls(service, count: 2)
        await service.complete(1, outcome: .success)
        await new.value
        await service.complete(0, outcome: .outputLimited) // 故意模拟忽略取消的迟到服务。
        await old.value
        XCTAssertEqual(fixture.model.state, .finished(ConnectionTestResult(outcome: .success, elapsedSeconds: 0.1)))
    }

    @MainActor
    func testFailureRestoresControlsAndKeepsOnlySanitizedError() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let task = try XCTUnwrap(fixture.model.start())
        try await awaitCalls(service, count: 1)
        await service.fail(0, error: URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: ProbeViewModelFixture.fakeKey]))
        await task.value
        XCTAssertEqual(fixture.model.state, .failed(.timedOut))
        XCTAssertTrue(fixture.model.canStart)
        XCTAssertFalse(String(describing: fixture.model.state).contains(ProbeViewModelFixture.fakeKey))
    }

    @MainActor
    func testOutputLimitedResultIsPreservedAsWarning() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        let task = try XCTUnwrap(fixture.model.start())
        try await awaitCalls(service, count: 1)
        await service.complete(0, outcome: .outputLimited)
        await task.value
        XCTAssertEqual(fixture.model.state, .finished(ConnectionTestResult(outcome: .outputLimited, elapsedSeconds: 0.1)))
        XCTAssertTrue(fixture.model.canStart)
    }

    @MainActor
    func testConnectionViewRendersLightAndDarkWithoutRequests() async throws {
        let service = ControlledProbeTester()
        let fixture = try ProbeViewModelFixture(service: service)
        defer { fixture.cleanUp() }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content:
                NavigationStack { ConnectionTestView(viewModel: fixture.model) }
                    .environment(\.enablesFocus, false)
                    .environment(\.colorScheme, scheme)
                    .frame(width: 402, height: 874)
            )
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, 402)
            XCTAssertEqual(image.size.height, 874)
        }
        let count = await service.calls.count
        XCTAssertEqual(count, 0)
    }

    @MainActor
    private func awaitCalls(_ service: ControlledProbeTester, count: Int) async throws {
        for _ in 0..<200 {
            if await service.calls.count >= count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Offline test service was not called within 2 seconds")
        throw URLError(.timedOut)
    }
}

@MainActor
private struct ProbeViewModelFixture {
    static let fakeKey = "odyssey-viewmodel-fixture-not-a-credential"
    let suiteName: String
    let defaults: UserDefaults
    let preferences: ConnectionTestPreferences
    let storage: MockConfigurationStorage
    let keychain: MockKeychainService
    let store: APIConfigurationStore
    let model: ConnectionTestViewModel

    init(service: any ConnectionTesting = ControlledProbeTester()) throws {
        suiteName = "com.kupetis.odyssey.tests.probe.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        preferences = ConnectionTestPreferences(defaults: defaults)
        storage = MockConfigurationStorage(initialConfiguration: APIConfiguration(baseURL: "https://example.invalid/v1", modelID: "fixture-model"))
        keychain = MockKeychainService()
        try keychain.saveAPIKey(Self.fakeKey)
        store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)
        model = ConnectionTestViewModel(store: store, service: service, preferences: preferences)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }
}

/// 可精确控制完成顺序，故意不响应任务取消以覆盖最坏的迟到回写情形。
private actor ControlledProbeTester: ConnectionTesting {
    struct Call: Sendable {
        let configuration: APIConfiguration
        let apiKey: String
        let outputLimit: Int
    }
    private(set) var calls: [Call] = []
    private var pending: [Int: CheckedContinuation<ConnectionTestResult, any Error>] = [:]

    func test(configuration: APIConfiguration, apiKey: String, outputLimit: Int) async throws -> ConnectionTestResult {
        let index = calls.count
        calls.append(Call(configuration: configuration, apiKey: apiKey, outputLimit: outputLimit))
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }
    func complete(_ index: Int, outcome: ConnectionTestOutcome) {
        pending.removeValue(forKey: index)?.resume(returning: ConnectionTestResult(outcome: outcome, elapsedSeconds: 0.1))
    }
    func fail(_ index: Int, error: any Error) {
        pending.removeValue(forKey: index)?.resume(throwing: error)
    }
}
