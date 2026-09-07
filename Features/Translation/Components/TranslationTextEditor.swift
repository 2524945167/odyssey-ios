import SwiftUI
import UIKit

/// Owns only the homepage editor. No global keyboard appearance or responder changes.
struct TranslationTextEditor: UIViewRepresentable {
    @Binding var text: String
    var isFocused: Binding<Bool>?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ThemeAwareTextView {
        let view = ThemeAwareTextView(frame: .zero, textContainer: nil)
        view.backgroundColor = .clear
        view.textColor = .label
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.textContainer.lineFragmentPadding = 5
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.keyboardDismissMode = .interactive
        view.accessibilityLabel = "输入文本"
        view.accessibilityIdentifier = "translation.sourceEditor"
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ThemeAwareTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.scheduleUpdate(uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ThemeAwareTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let proposedHeight = proposal.height ?? 110
        return CGSize(width: width, height: proposedHeight.isFinite ? max(110, proposedHeight) : 110)
    }

    static func dismantleUIView(_ uiView: ThemeAwareTextView, coordinator: Coordinator) {
        coordinator.cancelUpdate()
        uiView.delegate = nil
        uiView.resignFirstResponder()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TranslationTextEditor
        var isApplyingUpdate = false
        private var updateTask: Task<Void, Never>?

        init(_ parent: TranslationTextEditor) { self.parent = parent }

        func cancelUpdate() {
            updateTask?.cancel()
            updateTask = nil
        }

        func scheduleUpdate(_ view: ThemeAwareTextView) {
            cancelUpdate()
            // Responder changes can invalidate SwiftUI's keyboard safe area. Perform them
            // after the current updateUIView/layout transaction, using the latest bindings.
            updateTask = Task { @MainActor [weak self, weak view] in
                guard !Task.isCancelled, let self, let view, view.delegate === self else { return }
                self.isApplyingUpdate = true
                defer { self.isApplyingUpdate = false; self.updateTask = nil }
                let text = self.parent.text
                // Resigning may commit marked text; an explicit clear/swap wins afterwards.
                view.applyFocus(self.parent.isFocused?.wrappedValue)
                if view.text != text, view.markedTextRange == nil {
                    let selection = view.selectedRange
                    view.text = text
                    let length = (text as NSString).length
                    let location = min(selection.location, length)
                    view.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
                }
                view.synchronizeKeyboardAppearance()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingUpdate, parent.text != textView.text else { return }
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) { updateFocus(true) }
        func textViewDidEndEditing(_ textView: UITextView) { updateFocus(false) }

        private func updateFocus(_ value: Bool) {
            guard !isApplyingUpdate, let binding = parent.isFocused, binding.wrappedValue != value else { return }
            binding.wrappedValue = value
        }
    }
}

/// Derives appearance from current UIKit traits, never from the previous keyboard color.
/// Refreshes the existing responder without replacing its text, selection or marked text.
@MainActor
class ThemeAwareTextView: UITextView {
    private var requestedFocus: Bool?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ThemeAwareTextView, _: UITraitCollection) in
            view.synchronizeKeyboardAppearance()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:textContainer:)") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        synchronizeKeyboardAppearance()
        applyFocus(requestedFocus)
    }

    func applyFocus(_ focused: Bool?) {
        requestedFocus = focused
        guard let focused else { return }
        if focused, !isFirstResponder, window != nil {
            synchronizeKeyboardAppearance()
            becomeFirstResponder()
        } else if !focused, isFirstResponder {
            resignFirstResponder()
        }
    }

    func synchronizeKeyboardAppearance(forceReload: Bool = false) {
        let appearance: UIKeyboardAppearance
        switch traitCollection.userInterfaceStyle {
        case .dark: appearance = .dark
        case .light: appearance = .light
        default: return // Wait for resolved window traits; do not guess a theme.
        }
        guard keyboardAppearance != appearance || forceReload else { return }
        keyboardAppearance = appearance
        if isFirstResponder { reloadInputViews() }
    }

    @objc private func applicationDidBecomeActive() {
        guard window != nil else { return }
        // The keyboard extension may have been suspended while window traits changed.
        synchronizeKeyboardAppearance(forceReload: true)
    }
}
