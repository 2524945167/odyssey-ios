import SwiftUI

public struct TranslateButton: View {
    public var viewModel: TranslationViewModel
    public var onTranslate: () -> Void

    public init(viewModel: TranslationViewModel, onTranslate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onTranslate = onTranslate
    }

    public var body: some View {
        Button {
            if viewModel.isTranslating {
                viewModel.cancelTranslation()
            } else {
                onTranslate()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isTranslating {
                    ProgressView()
                        .tint(.white)
                    Text("停止翻译")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Text("翻译")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .disabled(!viewModel.canTranslate && !viewModel.isTranslating)
        .opacity(viewModel.canTranslate || viewModel.isTranslating ? 1.0 : 0.4)
        .padding(.horizontal, 20)
        .accessibilityLabel(viewModel.isTranslating ? "停止翻译" : "执行翻译")
        .accessibilityIdentifier("translation.action")
    }
}

#Preview {
    VStack(spacing: 16) {
        TranslateButton(viewModel: TranslationViewModel(sourceText: "你好")) {}
        TranslateButton(viewModel: TranslationViewModel()) {}
    }
}
