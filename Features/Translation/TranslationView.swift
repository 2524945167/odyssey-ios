import SwiftUI

public struct TranslationView: View {
    @State public var viewModel: TranslationViewModel
    @State private var showingSettings: Bool = false

    public init(viewModel: TranslationViewModel = TranslationViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LanguageSelector(viewModel: viewModel)
                        .padding(.top, 8)

                    SourceTextPanel(viewModel: viewModel)

                    TranslatedTextPanel(viewModel: viewModel)

                    TranslateButton(viewModel: viewModel) {
                        Task {
                            await viewModel.performMockTranslation()
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Odyssey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("打开设置")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - SwiftUI Previews

#Preview("空白状态") {
    TranslationView(viewModel: TranslationViewModel())
}

#Preview("已输入状态") {
    TranslationView(
        viewModel: TranslationViewModel(
            sourceText: "你好，欢迎使用 Odyssey 翻译！"
        )
    )
}

#Preview("已翻译状态") {
    TranslationView(
        viewModel: TranslationViewModel(
            sourceText: "你好，欢迎使用 Odyssey 翻译！",
            translatedText: "Hello, welcome to Odyssey Translation!"
        )
    )
}

#Preview("深色模式") {
    TranslationView(
        viewModel: TranslationViewModel(
            sourceText: "深色模式显示测试",
            translatedText: "Dark mode display test"
        )
    )
    .preferredColorScheme(.dark)
}
