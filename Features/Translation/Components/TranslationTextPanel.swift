import SwiftUI

public struct UnifiedTranslationPanel: View {
    @Bindable public var viewModel: TranslationViewModel
    @FocusState private var isSourceFocused: Bool
    @State private var showCopiedAlert: Bool = false

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 上半部分：原文编辑区
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.sourceLanguage.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !viewModel.sourceText.isEmpty {
                        Button {
                            viewModel.clearSource()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("清除文本")
                    }
                }

                ZStack(alignment: .topLeading) {
                    if viewModel.sourceText.isEmpty {
                        Text("输入文本")
                            .font(.body)
                            .foregroundColor(Color(uiColor: .placeholderText).opacity(0.8))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $viewModel.sourceText)
                        .font(.body)
                        .focused($isSourceFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                }
            }
            .padding(16)

            // 中间低对比度细分隔线
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.25))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            // 下半部分：译文显示区
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.targetLanguage.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        viewModel.copyTranslation()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopiedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopiedAlert = false
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                            if showCopiedAlert {
                                Text("已复制")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(viewModel.translatedText.isEmpty ? .secondary.opacity(0.4) : .blue)
                    }
                    .disabled(viewModel.translatedText.isEmpty)
                    .accessibilityLabel("复制译文")
                }

                ZStack(alignment: .topLeading) {
                    if viewModel.translatedText.isEmpty {
                        Text("翻译结果")
                            .font(.body)
                            .foregroundColor(Color(uiColor: .placeholderText).opacity(0.8))
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .frame(minHeight: 110)
                    } else {
                        ScrollView {
                            Text(viewModel.translatedText)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.top, 8)
                        }
                        .frame(minHeight: 110)
                    }
                }
            }
            .padding(16)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 16)
    }
}

#Preview {
    UnifiedTranslationPanel(viewModel: TranslationViewModel())
}
