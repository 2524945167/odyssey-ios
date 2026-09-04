import Foundation

/// 非敏感 API 配置存储协议
public protocol ConfigurationStorageProtocol: Sendable {
    func loadConfiguration() -> APIConfiguration?
    func saveConfiguration(_ configuration: APIConfiguration) throws
    func clearConfiguration()
}
