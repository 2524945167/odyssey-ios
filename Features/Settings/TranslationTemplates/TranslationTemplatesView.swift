import SwiftUI

public struct TranslationTemplatesView: View {
    private let preferences: TranslationPreferences

    public init(preferences: TranslationPreferences) { self.preferences = preferences }

    public var body: some View {
        Form {
            Section {
                Picker("当前风格", selection: Binding(
                    get: { preferences.styles.selectedStyle },
                    set: { preferences.selectStyle($0) }
                )) {
                    ForEach(TranslationStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.translationStyle.picker")
            } footer: {
                Text("选择后自动保存，用于下一次翻译。不会重新翻译已有内容，也不会改变正在进行的请求。")
            }

            Section {
                ForEach(TranslationStyle.allCases) { style in
                    NavigationLink {
                        TranslationTemplateEditorView(viewModel: TranslationTemplateViewModel(style: style, preferences: preferences))
                    } label: {
                        HStack {
                            Text(style.title)
                            Spacer()
                            if preferences.styles.isModified(style) {
                                Text(style == .custom ? "已设置" : "已修改")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("translationTemplate.\(style.rawValue)")
                }
            } header: {
                Text("编辑提示词")
            } footer: {
                Text("每份模板可独立编辑、保存或恢复默认。未填写自定义要求时，仅使用基础翻译规则。")
            }
        }
        .navigationTitle("翻译风格")
        .navigationBarTitleDisplayMode(.inline)
    }
}

public struct TranslationTemplateEditorView: View {
    @State private var viewModel: TranslationTemplateViewModel
    @FocusState private var isFocused: Bool

    public init(viewModel: TranslationTemplateViewModel) { _viewModel = State(initialValue: viewModel) }

    public var body: some View {
        @Bindable var model = viewModel
        Form {
            Section {
                TextEditor(text: $model.text)
                    .frame(minHeight: 220)
                    .focused($isFocused)
                    .accessibilityLabel("风格提示词")
                    .accessibilityIdentifier("translationTemplate.editor")
                if let error = viewModel.error { Text(error).font(.footnote).foregroundStyle(.red) }
            } header: {
                Text("风格要求")
            } footer: {
                Text("描述语气、用词、缩写或场景即可。语言方向、忠实原意和只输出译文由基础规则统一提供；不要在这里填写 API Key 或待翻译正文。模板保存在本机，选中后会随下一次翻译发送给当前服务商。")
            }

            Section {
                Button("保存") { isFocused = false; viewModel.save() }
                    .accessibilityIdentifier("translationTemplate.save")
                Button("恢复此模板默认值") { isFocused = false; viewModel.restoreDefaults() }
                    .accessibilityIdentifier("translationTemplate.restore")
                if viewModel.didSave {
                    Label("已保存", systemImage: "checkmark.circle").foregroundStyle(.green)
                }
            } footer: {
                Text("修改与恢复默认值都需要点击保存。返回而未保存的编辑会丢弃，不影响其他模板或正在进行的翻译。")
            }
        }
        .navigationTitle(viewModel.style.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isFocused = false }
            }
        }
    }
}
