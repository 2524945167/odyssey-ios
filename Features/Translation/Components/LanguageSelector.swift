import SwiftUI

public struct LanguageSelector: View {
    @Bindable public var viewModel: TranslationViewModel
    public var onShowLanguageHint: () -> Void

    public init(viewModel: TranslationViewModel, onShowLanguageHint: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onShowLanguageHint = onShowLanguageHint
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button {
                onShowLanguageHint()
            } label: {
                Text(viewModel.sourceLanguage.shortDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
            }
            .accessibilityLabel(viewModel.sourceLanguage.displayName)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.swapLanguages()
                }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(6)
            }
            .accessibilityLabel("交换语言")

            Button {
                onShowLanguageHint()
            } label: {
                Text(viewModel.targetLanguage.shortDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
            }
            .accessibilityLabel(viewModel.targetLanguage.displayName)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: Capsule())
    }
}

#Preview {
    LanguageSelector(viewModel: TranslationViewModel())
}
