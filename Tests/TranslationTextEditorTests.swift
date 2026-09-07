import XCTest
import SwiftUI
import UIKit
@testable import Odyssey

final class TranslationTextEditorTests: XCTestCase {
    @MainActor
    func testInitialAppearanceFollowsWindowWithoutOpeningKeyboard() async throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let editor = TrackingThemeTextView(frame: .zero, textContainer: nil)
            let fixture = try MountedWindowFixture(nativeView: editor, style: style)
            defer { fixture.close() }
            try await fixture.awaitStyle(style, editor: editor)
            XCTAssertFalse(editor.isFirstResponder)
            let reloads = editor.reloadCount
            editor.synchronizeKeyboardAppearance()
            XCTAssertEqual(editor.reloadCount, reloads)
        }
    }

    @MainActor
    func testRepeatedThemeChangesPreserveResponderTextAndSelection() async throws {
        let editor = TrackingThemeTextView(frame: .zero, textContainer: nil)
        let fixture = try MountedWindowFixture(nativeView: editor)
        defer { fixture.close() }
        editor.text = "你好，Odyssey 👋"
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.selectedRange = NSRange(location: 3, length: 7)
        let selection = editor.selectedRange
        for style in [UIUserInterfaceStyle.dark, .light, .dark, .light] {
            let reloads = editor.reloadCount
            fixture.window.overrideUserInterfaceStyle = style
            try await fixture.awaitStyle(style, editor: editor)
            XCTAssertGreaterThan(editor.reloadCount, reloads)
            XCTAssertTrue(editor.isFirstResponder)
            XCTAssertEqual(editor.text, "你好，Odyssey 👋")
            XCTAssertEqual(editor.selectedRange, selection)
        }
    }

    @MainActor
    func testThemeRefreshDoesNotDiscardMarkedText() async throws {
        let editor = TrackingThemeTextView(frame: .zero, textContainer: nil)
        let fixture = try MountedWindowFixture(nativeView: editor)
        defer { fixture.close() }
        editor.text = "中文组合输入："
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.selectedRange = NSRange(location: (editor.text as NSString).length, length: 0)
        editor.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))
        let marked = try XCTUnwrap(editor.markedTextRange)
        let markedString = editor.text(in: marked)
        let originalText = editor.text
        let selection = editor.selectedRange
        for style in [UIUserInterfaceStyle.dark, .light] {
            fixture.window.overrideUserInterfaceStyle = style
            try await fixture.awaitStyle(style, editor: editor)
            let currentMarked = try XCTUnwrap(editor.markedTextRange)
            XCTAssertEqual(editor.text(in: currentMarked), markedString)
            XCTAssertEqual(editor.text, originalText)
            XCTAssertEqual(editor.selectedRange, selection)
            XCTAssertTrue(editor.isFirstResponder)
        }
        editor.unmarkText()
        XCTAssertEqual(editor.text, originalText)
    }

    @MainActor
    func testForegroundRefreshKeepsCurrentThemeAndResponder() throws {
        let editor = TrackingThemeTextView(frame: .zero, textContainer: nil)
        let fixture = try MountedWindowFixture(nativeView: editor, style: .dark)
        defer { fixture.close() }
        editor.text = "保留原文"
        XCTAssertTrue(editor.becomeFirstResponder())
        let reloads = editor.reloadCount
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertGreaterThan(editor.reloadCount, reloads)
        XCTAssertEqual(editor.keyboardAppearance, .dark)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(editor.text, "保留原文")
    }

    @MainActor
    func testDismissThenReopenUsesLatestTheme() async throws {
        let editor = TrackingThemeTextView(frame: .zero, textContainer: nil)
        let fixture = try MountedWindowFixture(nativeView: editor)
        defer { fixture.close() }
        editor.text = "重新打开后仍保留"
        editor.applyFocus(true)
        XCTAssertTrue(editor.isFirstResponder)
        editor.applyFocus(false)
        XCTAssertFalse(editor.isFirstResponder)
        fixture.window.overrideUserInterfaceStyle = .dark
        try await fixture.awaitStyle(.dark, editor: editor)
        XCTAssertFalse(editor.isFirstResponder)
        editor.applyFocus(true)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(editor.keyboardAppearance, .dark)
        XCTAssertEqual(editor.text, "重新打开后仍保留")
    }

    @MainActor
    func testSwiftUIBindingSupportsTypingClearAndFocusInBothDirections() async throws {
        let state = EditorTestState()
        let fixture = try MountedWindowFixture(rootView: EditorTestHarness(state: state))
        defer { fixture.close() }
        try await fixture.awaitCondition { self.findEditor(in: fixture.host.view) != nil }
        let editor = try XCTUnwrap(findEditor(in: fixture.host.view))
        state.isFocused = true
        try await fixture.awaitCondition { editor.isFirstResponder }
        editor.insertText("你好，世界")
        try await fixture.awaitCondition { state.text == "你好，世界" }
        state.isFocused = false
        try await fixture.awaitCondition { !editor.isFirstResponder }
        XCTAssertEqual(editor.text, state.text)
        XCTAssertTrue(editor.becomeFirstResponder())
        try await fixture.awaitCondition { state.isFocused }
        state.text = ""
        try await fixture.awaitCondition { editor.text.isEmpty }
        XCTAssertEqual(editor.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertTrue(editor.resignFirstResponder())
        try await fixture.awaitCondition { !state.isFocused }
    }

    @MainActor
    func testHomepageKeepsSameNativeEditorAcrossThemesAndRenders() async throws {
        let model = TranslationViewModel(sourceText: "首页原文 👋", translatedText: "Homepage result")
        let fixture = try MountedWindowFixture(rootView: TranslationView(viewModel: model))
        defer { fixture.close() }
        try await fixture.awaitCondition { self.findEditor(in: fixture.host.view) != nil }
        let original = try XCTUnwrap(findEditor(in: fixture.host.view))
        for style in [UIUserInterfaceStyle.light, .dark] {
            fixture.window.overrideUserInterfaceStyle = style
            try await fixture.awaitStyle(style, editor: original)
            XCTAssertTrue(findEditor(in: fixture.host.view) === original)
            XCTAssertEqual(original.text, model.sourceText)
            XCTAssertGreaterThanOrEqual(original.bounds.height, 110)
            XCTAssertFalse(original.isFirstResponder)
            let image = UIGraphicsImageRenderer(size: fixture.window.bounds.size).image { _ in
                XCTAssertTrue(fixture.host.view.drawHierarchy(in: fixture.window.bounds, afterScreenUpdates: true))
            }
            XCTAssertEqual(image.size, CGSize(width: 402, height: 874))
            let attachment = XCTAttachment(image: image)
            attachment.name = style == .light ? "Round6-Homepage-Light" : "Round6-Homepage-Dark"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func findEditor(in view: UIView) -> ThemeAwareTextView? {
        if let editor = view as? ThemeAwareTextView { return editor }
        for child in view.subviews {
            if let editor = findEditor(in: child) { return editor }
        }
        return nil
    }
}

@MainActor
private final class TrackingThemeTextView: ThemeAwareTextView {
    private(set) var reloadCount = 0
    override func reloadInputViews() {
        reloadCount += 1
        super.reloadInputViews()
    }
}

@MainActor @Observable
private final class EditorTestState {
    var text = ""
    var isFocused = false
}

private struct EditorTestHarness: View {
    @Bindable var state: EditorTestState
    var body: some View {
        TranslationTextEditor(text: $state.text, isFocused: $state.isFocused)
            .frame(height: 160)
            .padding()
    }
}

@MainActor
final class MountedWindowFixture {
    let window: UIWindow
    let host: UIViewController
    private let previousKeyWindow: UIWindow?

    convenience init<Content: View>(rootView: Content) throws {
        try self.init(host: UIHostingController(rootView: rootView), style: .light)
    }

    convenience init(nativeView: ThemeAwareTextView, style: UIUserInterfaceStyle = .light) throws {
        let host = UIViewController()
        host.loadViewIfNeeded()
        nativeView.frame = CGRect(x: 16, y: 100, width: 370, height: 160)
        host.view.addSubview(nativeView)
        try self.init(host: host, style: style)
    }

    private init(host: UIViewController, style: UIUserInterfaceStyle) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        self.host = host
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
    }

    func close() {
        host.view.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }

    func awaitStyle(_ style: UIUserInterfaceStyle, editor: ThemeAwareTextView) async throws {
        try await awaitCondition {
            editor.traitCollection.userInterfaceStyle == style &&
                editor.keyboardAppearance == (style == .dark ? .dark : .light)
        }
    }

    func awaitCondition(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Mounted editor did not reach the expected state within 2 seconds")
        throw NSError(domain: "Odyssey.EditorTests", code: 1)
    }
}
