import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "简体中文"
    case english = "英语"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}
