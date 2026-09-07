import Foundation

public enum TranslationStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    // gaming 保留为持久化标识，升级后不丢失旧选择或用户编辑的模板。
    case natural, casual, gaming, business, custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .natural: return "自然表达"
        case .casual: return "口语聊天"
        case .gaming: return "网络聊天"
        case .business: return "正式商务"
        case .custom: return "自定义"
        }
    }

    public var defaultInstructions: String {
        switch self {
        case .natural:
            return "使用自然、地道的目标语言，避免机械逐字翻译。保持原文的语气、情绪和正式程度，不擅自润色、扩写或改变意思。"
        case .casual:
            return "使用适合日常聊天的自然口语，可使用目标语言中常见的缩合表达。保持原文的亲疏程度、情绪和礼貌程度，不添加称呼、表情或原文没有的内容。"
        case .gaming:
            return "使用适合社交平台、群聊、私信和游戏交流的简短、自然表达。在意思准确、语境合适且对方容易理解时，优先使用目标语言中常见的网络用语、缩写或缩合表达；否则使用完整表达。例如英文聊天中的“我马上回来”可译为 brb，但不要给无关内容添加 brb、gg、lol。根据上下文判断是否为游戏场景，不把普通聊天强行改成游戏术语。保留人名、专有名词、数字、否定和行动要求，不为缩短文本遗漏信息，也不擅自添加表情或攻击性语言。"
        case .business:
            return "使用专业、礼貌、准确的商务表达，避免俚语和随意缩写。保留原文的语气强度、责任归属、日期、金额和不确定性，不擅自增加承诺、保证、道歉或客套内容。"
        case .custom:
            return ""
        }
    }
}

/// 用户编辑的是风格要求；固定翻译规则与原文不存入模板。
public struct TranslationStyleConfiguration: Codable, Equatable, Sendable {
    public var selectedStyle: TranslationStyle = .natural
    public var overrides: [String: String] = [:]

    public init() {}

    public func instructions(for style: TranslationStyle) -> String {
        overrides[style.rawValue] ?? style.defaultInstructions
    }

    public func isModified(_ style: TranslationStyle) -> Bool {
        instructions(for: style) != style.defaultInstructions
    }
}
