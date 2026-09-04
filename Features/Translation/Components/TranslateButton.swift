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
            onTranslate()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isTranslating {
                    ProgressView()
                        .tint(.white)
                    Text("正在翻译...")
                        .font(.headline)
                        .fontWeight(.semibold)
                } else {
                    Text("翻译")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canTranslate ? Color.blue : Color(uiColor: .systemGray4))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!viewModel.canTranslate)
        .padding(.horizontal)
        .accessibilityLabel("执行翻译")
    }
}

#Preview {
    VStack(spacing: 16) {
        TranslateButton(viewModel: TranslationViewModel(sourceText: "你好")) {}
        TranslateButton(viewModel: TranslationViewModel()) {}
    }
}
