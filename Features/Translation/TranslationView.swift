import SwiftUI

public struct TranslationView: View {
    @Environment(\.enablesFocus) private var enablesFocus
    @State public var viewModel: TranslationViewModel
    @State private var isInputFocused: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showLanguageToast: Bool = false

    @MainActor
    public init(viewModel: TranslationViewModel = TranslationViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    private func dismissKeyboard() {
        guard enablesFocus else { return }
        if isInputFocused {
            isInputFocused = false
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // 根背景响应层：点击页面任意非交互空白区域收起键盘
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            ScrollView {
                GlassEffectContainer(spacing: 14) {
                    VStack(spacing: 14) {
                        TopBrandBar(
                            onOpenSettings: {
                                dismissKeyboard()
                                showingSettings = true
                            },
                            onTapBackground: {
                                dismissKeyboard()
                            }
                        )

                        LanguageSelector(
                            viewModel: viewModel,
                            onShowLanguageHint: {
                                dismissKeyboard()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showLanguageToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showLanguageToast = false
                                    }
                                }
                            },
                            onSwap: {
                                dismissKeyboard()
                            }
                        )

                        UnifiedTranslationPanel(
                            viewModel: viewModel,
                            isInputFocused: enablesFocus ? $isInputFocused : nil
                        )
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
            }

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
        .safeAreaInset(edge: .bottom) {
            TranslateButton(viewModel: viewModel) {
                dismissKeyboard()
                Task {
                    await viewModel.performMockTranslation()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial.opacity(0.35))
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
