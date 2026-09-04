import SwiftUI

public struct LanguageSelector: View {
    @Bindable public var viewModel: TranslationViewModel

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack {
            Text(viewModel.sourceLanguage.displayName)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("交换语言")

            Text(viewModel.targetLanguage.displayName)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

#Preview {
    LanguageSelector(viewModel: TranslationViewModel())
}
