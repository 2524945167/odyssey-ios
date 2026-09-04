import Foundation

/// 非敏感 API 配置模型
/// 严格仅包含 API 格式、服务地址与模型 ID，绝不包含 API Key。
/// 专用于持久化至非敏感存储（如 UserDefaults）。
public struct APIConfiguration: Codable, Equatable, Sendable {
    public var apiFormat: APIFormat
    public var baseURL: String
    public var modelID: String

    public static let `default` = APIConfiguration(
        apiFormat: .openAIResponses,
        baseURL: "https://api.openai.com",
        modelID: "gpt-4o"
    )

    public init(
        apiFormat: APIFormat = .default,
        baseURL: String = APIFormat.default.defaultBaseURL ?? "",
        modelID: String = "gpt-4o"
    ) {
        self.apiFormat = apiFormat
        self.baseURL = baseURL
        self.modelID = modelID
    }
}
