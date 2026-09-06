import Foundation
import Observation

@Observable
@MainActor
public final class ConnectionTestViewModel {
    public private(set) var state: ConnectionTestState = .idle
    public private(set) var configuration: APIConfiguration?
    public private(set) var hasSavedKey: Bool
    public private(set) var outputLimitError: String?
    public var outputLimitText: String {
        didSet {
            guard oldValue != outputLimitText else { return }
            outputLimitError = nil
            if !isTesting { state = .idle }
        }
    }

    @ObservationIgnored private let store: APIConfigurationStore
    @ObservationIgnored private let service: any ConnectionTesting
    @ObservationIgnored private let preferences: ConnectionTestPreferences
    @ObservationIgnored private var runningTask: Task<Void, Never>?
    @ObservationIgnored private var activeID: UUID?

    public init(
        store: APIConfigurationStore,
        service: any ConnectionTesting = ConnectionTestService(),
        preferences: ConnectionTestPreferences = ConnectionTestPreferences()
    ) {
        self.store = store
        self.service = service
        self.preferences = preferences
        configuration = store.configurationStorage.loadConfiguration()
        hasSavedKey = store.hasSavedAPIKey
        outputLimitText = String(preferences.outputLimit)
    }

    deinit { runningTask?.cancel() }

    public var isTesting: Bool { state == .running }
    public var canStart: Bool { !isTesting && configuration != nil && hasSavedKey }
    public var endpointText: String? {
        guard let configuration else { return nil }
        return try? APIProbeRequestBuilder.endpoint(for: configuration).absoluteString
    }

    public func refreshConfiguration() {
        let saved = store.configurationStorage.loadConfiguration()
        let hasKey = store.hasSavedAPIKey
        if configuration != saved || hasSavedKey != hasKey {
            cancel()
            state = .idle
        }
        configuration = saved
        hasSavedKey = hasKey
    }

    public func resetOutputLimit() {
        guard !isTesting else { return }
        outputLimitText = String(ConnectionTestPolicy.defaultOutputLimit)
    }

    /// 返回可等待的任务，便于离线测试精确验证结束状态；重复点击不创建第二个任务。
    @discardableResult
    public func start() -> Task<Void, Never>? {
        guard !isTesting else { return nil }
        refreshConfiguration()
        outputLimitError = nil
        let outputLimit: Int
        do {
            outputLimit = try ConnectionTestPolicy.outputLimit(from: outputLimitText)
        } catch {
            outputLimitError = ConnectionTestError.invalidOutputLimit.errorDescription
            state = .failed(.invalidOutputLimit)
            return nil
        }
        guard let configuration, hasSavedKey else {
            state = .failed(.notConfigured)
            return nil
        }
        let apiKey: String
        do {
            apiKey = try store.keychainService.readAPIKey()
        } catch {
            state = .failed(.keychainUnavailable)
            return nil
        }
        do {
            // 请求前校验；不写入原有 API 配置，不修改/重新保存密钥。
            _ = try APIProbeRequestBuilder.build(configuration: configuration, apiKey: apiKey, outputLimit: outputLimit)
            try preferences.saveOutputLimit(outputLimit)
        } catch {
            state = .failed(ConnectionTestError.sanitized(error))
            return nil
        }
        outputLimitText = String(outputLimit)
        let id = UUID()
        activeID = id
        state = .running
        let service = self.service
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await service.test(configuration: configuration, apiKey: apiKey, outputLimit: outputLimit)
                guard !Task.isCancelled, let self, self.activeID == id else { return }
                self.state = .finished(result)
                self.activeID = nil
                self.runningTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.activeID == id else { return }
                let safeError = ConnectionTestError.sanitized(error)
                self.state = safeError == .cancelled ? .cancelled : .failed(safeError)
                self.activeID = nil
                self.runningTask = nil
            }
        }
        runningTask = task
        return task
    }

    public func cancel() {
        guard isTesting else { return }
        // 先失效请求标识，即使旧服务忽略取消也不能覆盖新测试结果。
        activeID = nil
        runningTask?.cancel()
        runningTask = nil
        state = .cancelled
    }
}
