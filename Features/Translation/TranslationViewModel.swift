import Foundation
import SwiftUI

@Observable
@MainActor
public final class TranslationViewModel {
    public var sourceText: String {
        didSet { if oldValue != sourceText { sourceDidChange() } }
    }
    public var translatedText: String = ""
    public var sourceLanguage: AppLanguage {
        didSet { if oldValue != sourceLanguage { sourceDidChange() } }
    }
    public var targetLanguage: AppLanguage {
        didSet { if oldValue != targetLanguage { sourceDidChange() } }
    }
    public private(set) var state: TranslationState = .idle

    @ObservationIgnored public let configurationStore: APIConfigurationStore
    @ObservationIgnored public let preferences: TranslationPreferences
    @ObservationIgnored private let clipboard: any ClipboardWriting
    @ObservationIgnored private let service: any TranslationServing
    @ObservationIgnored private var runningTask: Task<Void, Never>?
    @ObservationIgnored private var activeID: UUID?
    @ObservationIgnored private var isChangingContent = false

    public var isTranslating: Bool { state == .running }

    public var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }

    public init(
        sourceText: String = "",
        translatedText: String = "",
        sourceLanguage: AppLanguage = .chinese,
        targetLanguage: AppLanguage = .english,
        clipboard: any ClipboardWriting = SystemClipboardWriter(),
        store: APIConfigurationStore = APIConfigurationStore(),
        preferences: TranslationPreferences = TranslationPreferences(),
        service: any TranslationServing = TranslationService()
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.clipboard = clipboard
        configurationStore = store
        self.preferences = preferences
        self.service = service
    }

    deinit { runningTask?.cancel() }

    public func clearSource() {
        invalidateTask()
        isChangingContent = true
        sourceText = ""
        translatedText = ""
        isChangingContent = false
        state = .idle
    }

    public func swapLanguages() {
        invalidateTask()
        isChangingContent = true
        let previousSource = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = previousSource

        if !translatedText.isEmpty {
            let previousSourceText = sourceText
            sourceText = translatedText
            translatedText = previousSourceText
        }
        isChangingContent = false
        state = translatedText.isEmpty ? .idle : .sourceChanged
    }

    public func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        clipboard.setString(translatedText)
    }

    /// 只由显式按钮操作调用。原文、语言、配置、参数均为本次请求的快照。
    /// 返回可等待任务供测试使用；生产界面不再包含模拟翻译路径。
    @discardableResult
    public func startTranslation() -> Task<Void, Never>? {
        guard canTranslate else { return nil }
        guard let configuration = configurationStore.configurationStorage.loadConfiguration() else {
            state = .failed(.notConfigured)
            return nil
        }
        let apiKey: String
        do {
            apiKey = try configurationStore.keychainService.readAPIKey()
        } catch {
            state = .failed((error as? KeychainError) == .itemNotFound ? .notConfigured : .keychainUnavailable)
            return nil
        }
        let source = sourceText
        let from = sourceLanguage
        let to = targetLanguage
        let options = preferences.options
        do {
            _ = try TranslationService.validatedRequest(configuration: configuration, apiKey: apiKey, source: source,
                                                        sourceLanguage: from, targetLanguage: to, options: options)
        } catch {
            state = .failed(.request(StreamingError.sanitized(error)))
            return nil
        }
        let id = UUID()
        activeID = id
        translatedText = ""
        state = .running
        let service = self.service
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await service.translate(
                    configuration: configuration, apiKey: apiKey, source: source,
                    sourceLanguage: from, targetLanguage: to, options: options
                ) { [weak self] text in
                    guard let self else { throw CancellationError() }
                    try await self.receive(text, requestID: id)
                }
                guard !Task.isCancelled, let self, self.activeID == id else { return }
                self.state = .finished(result)
                self.activeID = nil
                self.runningTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.activeID == id else { return }
                let safeError = StreamingError.sanitized(error)
                self.state = safeError == .cancelled ? .cancelled : .failed(.request(safeError))
                self.activeID = nil
                self.runningTask = nil
            }
        }
        runningTask = task
        return task
    }

    public func cancelTranslation() {
        guard isTranslating else { return }
        invalidateTask()
        state = .cancelled
    }

    private func receive(_ text: String, requestID: UUID) throws {
        try Task.checkCancellation()
        guard activeID == requestID, isTranslating else { throw CancellationError() }
        translatedText.append(text)
    }

    private func sourceDidChange() {
        guard !isChangingContent else { return }
        let wasRunning = isTranslating
        invalidateTask()
        state = wasRunning || !translatedText.isEmpty ? .sourceChanged : .idle
    }

    private func invalidateTask() {
        // 必须先失效 ID，再取消任务；迟到的增量/终态/错误都不能覆盖新结果。
        activeID = nil
        runningTask?.cancel()
        runningTask = nil
    }
}
