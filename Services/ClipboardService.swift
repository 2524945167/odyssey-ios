import UIKit

public protocol ClipboardWriting: Sendable {
    func setString(_ string: String)
    func getString() -> String?
}

public final class SystemClipboardWriter: ClipboardWriting {
    public init() {}

    @MainActor
    public func setString(_ string: String) {
        UIPasteboard.general.string = string
    }

    @MainActor
    public func getString() -> String? {
        UIPasteboard.general.string
    }
}

public final class MockClipboardWriter: ClipboardWriting, @unchecked Sendable {
    public var storedString: String?

    public init(storedString: String? = nil) {
        self.storedString = storedString
    }

    public func setString(_ string: String) {
        storedString = string
    }

    public func getString() -> String? {
        storedString
    }
}
