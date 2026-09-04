import SwiftUI

public struct SourceTextPanel: View {
    @Bindable public var viewModel: TranslationViewModel
    @FocusState private var isFocused: Bool

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.sourceLanguage.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !viewModel.sourceText.isEmpty {
                    Button {
                        viewModel.clearSource()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                    }
                    .accessibilityLabel("清除原文与译文")
                }
            }

            ZStack(alignment: .topLeading) {
                if viewModel.sourceText.isEmpty {
                    Text("输入文本")
                        .font(.body)
                        .foregroundColor(Color(uiColor: .placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.sourceText)
                    .font(.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

public struct TranslatedTextPanel: View {
    public var viewModel: TranslationViewModel
    @State private var showCopiedAlert: Bool = false

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.targetLanguage.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    viewModel.copyTranslation()
                    withAnimation {
                        showCopiedAlert = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopiedAlert = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14))
                        if showCopiedAlert {
                            Text("已复制")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(viewModel.translatedText.isEmpty ? .secondary.opacity(0.5) : .blue)
                }
                .disabled(viewModel.translatedText.isEmpty)
                .accessibilityLabel("复制译文")
            }

            ZStack(alignment: .topLeading) {
                if viewModel.translatedText.isEmpty {
                    Text("翻译结果")
                        .font(.body)
                        .foregroundColor(Color(uiColor: .placeholderText))
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(minHeight: 140)
                } else {
                    ScrollView {
                        Text(viewModel.translatedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.top, 8)
                    }
                    .frame(minHeight: 140)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 16) {
        SourceTextPanel(viewModel: TranslationViewModel())
        TranslatedTextPanel(viewModel: TranslationViewModel())
    }
}
