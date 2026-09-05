import SwiftUI
import Observation
import UIKit

/// API 配置输入字段枚举，用于 @FocusState 聚焦定位
public enum APIFormField: Hashable, Sendable {
    case baseURL
    case modelID
    case apiKey
}

/// API 配置页面 ViewModel
/// 统一管理强类型 API 配置、本地脱敏校验、钥匙串存储及输入框状态
@Observable
@MainActor
public final class APIConfigurationViewModel {

    // MARK: - Dependencies
    public let store: APIConfigurationStore
    nonisolated private var resignActiveObserver: (any NSObjectProtocol)?

    // MARK: - Form State
    public var apiFormat: APIFormat {
        didSet {
            guard oldValue != apiFormat else { return }
            handleFormatChange(from: oldValue, to: apiFormat)
        }
    }

    /// 明确跟踪 Base URL 是否已被用户手动编辑
    /// 自动填写的地址可随格式切换；用户手动修改后不得被格式切换覆盖。
    public var isBaseURLCustomized: Bool = false
    private var isProgrammaticBaseURLChange: Bool = false

    public var baseURL: String {
        didSet {
            baseURLValidationError = nil
            if !isProgrammaticBaseURLChange {
                isBaseURLCustomized = true
            }
        }
    }

    public var modelID: String {
        didSet {
            modelIDValidationError = nil
        }
    }

    public var apiKeyInput: String {
        didSet {
            apiKeyValidationError = nil
        }
    }

    // MARK: - UI & Security State
    public var isAPIKeyVisible: Bool = false
    public var hasSavedAPIKey: Bool
    public var showClearConfirmation: Bool = false
    public var saveSuccessMessage: String?
    public var errorMessage: String?

    // MARK: - Inline Validation Errors
    public var baseURLValidationError: String?
    public var modelIDValidationError: String?
    public var apiKeyValidationError: String?

    // MARK: - Initializer
    public init(store: APIConfigurationStore = APIConfigurationStore()) {
        self.store = store

        if let savedConfig = store.configurationStorage.loadConfiguration() {
            self.apiFormat = savedConfig.apiFormat
            self.baseURL = savedConfig.baseURL
            self.modelID = savedConfig.modelID
            self.isBaseURLCustomized = (savedConfig.baseURL != savedConfig.apiFormat.defaultBaseURL)
        } else {
            self.apiFormat = .openAIResponses
            self.baseURL = APIFormat.openAIResponses.defaultBaseURL ?? ""
            self.modelID = ""
            self.isBaseURLCustomized = false
        }

        self.hasSavedAPIKey = store.hasSavedAPIKey
        self.apiKeyInput = ""

        self.resignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hideAPIKey()
            }
        }
    }

    deinit {
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Format Change & Auto-fill
    private func handleFormatChange(from oldFormat: APIFormat, to newFormat: APIFormat) {
        if !isBaseURLCustomized {
            isProgrammaticBaseURLChange = true
            baseURL = newFormat.defaultBaseURL ?? ""
            isProgrammaticBaseURLChange = false
        }
        baseURLValidationError = nil
    }

    // MARK: - Reset Actions
    public func resetBaseURLToDefault() {
        isProgrammaticBaseURLChange = true
        baseURL = apiFormat.defaultBaseURL ?? ""
        isProgrammaticBaseURLChange = false
        isBaseURLCustomized = false
        baseURLValidationError = nil
    }

    // MARK: - Validation
    /// 执行表单校验，若有错误返回首个错误字段供视图定位焦点
    @discardableResult
    public func validate() -> APIFormField? {
        baseURLValidationError = nil
        modelIDValidationError = nil
        apiKeyValidationError = nil

        var firstErrorField: APIFormField?

        do {
            try APIConfigurationValidator.validateBaseURL(baseURL)
        } catch {
            baseURLValidationError = error.localizedDescription
            if firstErrorField == nil { firstErrorField = .baseURL }
        }

        do {
            try APIConfigurationValidator.validateModelID(modelID)
        } catch {
            modelIDValidationError = error.localizedDescription
            if firstErrorField == nil { firstErrorField = .modelID }
        }

        do {
            try APIConfigurationValidator.validateAPIKey(inputKey: apiKeyInput, hasSavedKey: hasSavedAPIKey)
        } catch {
            apiKeyValidationError = error.localizedDescription
            if firstErrorField == nil { firstErrorField = .apiKey }
        }

        return firstErrorField
    }

    // MARK: - Save Action
    @discardableResult
    public func save() -> Bool {
        if let _ = validate() {
            return false
        }

        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = APIConfiguration(
            apiFormat: apiFormat,
            baseURL: trimmedURL,
            modelID: trimmedModel
        )

        do {
            try store.save(configuration: configuration, newAPIKey: apiKeyInput)
            hasSavedAPIKey = store.hasSavedAPIKey
            apiKeyInput = ""
            isAPIKeyVisible = false
            saveSuccessMessage = "配置已成功保存"
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Clear API Key Action
    public func clearAPIKey() {
        do {
            try store.clearAPIKey()
            hasSavedAPIKey = false
            apiKeyInput = ""
            isAPIKeyVisible = false
            saveSuccessMessage = "已安全清除 API Key"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Privacy
    public func hideAPIKey() {
        if isAPIKeyVisible {
            isAPIKeyVisible = false
        }
    }
}
