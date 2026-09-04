import SwiftUI

public struct TranslationView: View {
    @State public var viewModel: TranslationViewModel
    @State private var showingSettings: Bool = false
    @State private var showLanguageToast: Bool = false

    @MainActor
    public init(viewModel: TranslationViewModel = TranslationViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    GlassEffectContainer(spacing: 14) {
                        VStack(spacing: 14) {
                            TopBrandBar {
                                showingSettings = true
                            }

                            LanguageSelector(viewModel: viewModel) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showLanguageToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showLanguageToast = false
                                    }
                                }
                            }

                            UnifiedTranslationPanel(viewModel: viewModel)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                // 轻量语言选择提示 Toast
                if showLanguageToast {
                    Text("完整语言选择将在后续实现")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 52)
                        .zIndex(10)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                TranslateButton(viewModel: viewModel) {
                    Task {
                        await viewModel.performMockTranslation()
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial.opacity(0.35))
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
