import Foundation
import Observation

/// 设置页面 ViewModel
/// 管理设置主页的可观察状态，确保配置更新后摘要即时刷新
@Observable
@MainActor
public final class SettingsViewModel {
    public let store: APIConfigurationStore
    public var configurationSummary: String

    public init(store: APIConfigurationStore = APIConfigurationStore()) {
        self.store = store
        self.configurationSummary = store.summaryText
    }

    /// 刷新配置摘要
    public func refreshSummary() {
        configurationSummary = store.summaryText
    }
}
