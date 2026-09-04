import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "简体中文"
    case english = "英语"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public var shortDisplayName: String {
        switch self {
        case .chinese:
            return "中"
        case .english:
            return "英"
        }
    }
}
