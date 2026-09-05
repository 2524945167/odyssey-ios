import SwiftUI

private struct EnablesFocusKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// 控制视图层次是否启用 FocusState 焦点子系统
    /// 交互环境默认为 true；离线测试渲染容器（如 ImageRenderer）可置为 false，
    /// 避免在无活动 UIWindow 场景下触发系统警告 "Accessing FocusState's value outside of the body of a View"。
    public var enablesFocus: Bool {
        get { self[EnablesFocusKey.self] }
        set { self[EnablesFocusKey.self] = newValue }
    }
}
