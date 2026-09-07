import Foundation

/// 正式翻译独立参数；不借用连接测试的 256 tokens / 30 秒。
public struct TranslationOptions: Equatable, Sendable {
    public static let defaultOutputLimit = 8192
    public static let defaultIdleTimeoutSeconds = 60
    public static let maximumDuration: TimeInterval = 300

    public let outputLimit: Int
    public let idleTimeoutSeconds: Int

    public init(outputLimit: Int = Self.defaultOutputLimit,
                idleTimeoutSeconds: Int = Self.defaultIdleTimeoutSeconds) {
        self.outputLimit = outputLimit
        self.idleTimeoutSeconds = idleTimeoutSeconds
    }

    public var isValid: Bool { outputLimit > 0 && idleTimeoutSeconds > 0 }

    /// 不猜测服务商上限，不静默截断或改小用户输入。
    public static func positiveInteger(from text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = Int(value), number > 0 else { return nil }
        return number
    }
}
