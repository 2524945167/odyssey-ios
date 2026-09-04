import UIKit

@MainActor
public protocol ClipboardWriting: Sendable {
    func setString(_ string: String)
    func getString() -> String?
}

@MainActor
public final class SystemClipboardWriter: ClipboardWriting {
    public init() {}

    public func setString(_ string: String) {
        UIPasteboard.general.string = string
    }

    public func getString() -> String? {
        UIPasteboard.general.string
    }
}

@MainActor
public final class MockClipboardWriter: ClipboardWriting {
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
