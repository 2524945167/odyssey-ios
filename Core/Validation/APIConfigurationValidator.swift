import Foundation

/// API 校验强类型错误枚举
public enum APIValidationError: LocalizedError, Equatable, Sendable {
    case emptyBaseURL
    case invalidScheme
    case missingHost
    case containsCredentials
    case containsQueryOrFragment
    case invalidURL
    case emptyModelID
    case missingAPIKey
    case emptyAPIKey

    public var errorDescription: String? {
        switch self {
        case .emptyBaseURL:
            return "服务地址不能为空"
        case .invalidScheme:
            return "服务地址必须使用 HTTPS 协议（禁止 HTTP）"
        case .missingHost:
            return "服务地址缺少有效的主机名"
        case .containsCredentials:
            return "服务地址不能嵌入用户名或密码"
        case .containsQueryOrFragment:
            return "服务地址不能包含参数或定位符（? 或 #）"
        case .invalidURL:
            return "服务地址格式无效"
        case .emptyModelID:
            return "Model ID 不能为空"
        case .missingAPIKey:
            return "请输入 API Key"
        case .emptyAPIKey:
            return "API Key 不能仅包含空格或换行"
        }
    }
}

/// API 配置校验器
/// 纯函数式脱敏验证，严格遵循安全规范。
public enum APIConfigurationValidator {

    /// 校验 Base URL
    public static func validateBaseURL(_ urlString: String) throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIValidationError.emptyBaseURL
        }

        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else {
            throw APIValidationError.invalidURL
        }

        guard scheme == "https" else {
            throw APIValidationError.invalidScheme
        }

        guard let host = components.host, !host.isEmpty else {
            throw APIValidationError.missingHost
        }

        guard components.user == nil && components.password == nil else {
            throw APIValidationError.containsCredentials
        }

        guard components.query == nil && components.fragment == nil else {
            throw APIValidationError.containsQueryOrFragment
        }

        guard components.url != nil else {
            throw APIValidationError.invalidURL
        }
    }

    /// 校验 Model ID
    public static func validateModelID(_ modelID: String) throws {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIValidationError.emptyModelID
        }
    }

    /// 校验 API Key
    /// - Parameters:
    ///   - inputKey: 用户当前在输入框键入的文本
    ///   - hasSavedKey: 本机 Keychain 中是否已有安全保存的旧密钥
    public static func validateAPIKey(inputKey: String, hasSavedKey: Bool) throws {
        if inputKey.isEmpty {
            if !hasSavedKey {
                throw APIValidationError.missingAPIKey
            }
            // 已有密钥且输入框为空代表保留原密钥，通过校验
            return
        }

        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIValidationError.emptyAPIKey
        }
    }

    /// 综合校验全部字段
    public static func validate(
        baseURL: String,
        modelID: String,
        inputKey: String,
        hasSavedKey: Bool
    ) throws {
        try validateBaseURL(baseURL)
        try validateModelID(modelID)
        try validateAPIKey(inputKey: inputKey, hasSavedKey: hasSavedKey)
    }
}
