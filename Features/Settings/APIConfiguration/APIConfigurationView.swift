import SwiftUI

/// API 配置详情表单视图
/// 提供格式选择、端点输入、模型配置与钥匙串凭证管理
public struct APIConfigurationView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.enablesFocus) private var enablesFocus

    @Bindable public var viewModel: APIConfigurationViewModel
    @FocusState private var focusedField: APIFormField?

    @MainActor
    public init(viewModel: APIConfigurationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            // MARK: - 错误提示横幅
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            // MARK: - API 格式选择
            Section {
                Picker("格式类型", selection: $viewModel.apiFormat) {
                    ForEach(APIFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("API 协议格式")
            } footer: {
                Text(viewModel.apiFormat.descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // MARK: - 服务端点与模型
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Base URL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let defaultURL = viewModel.apiFormat.defaultBaseURL,
                           viewModel.baseURL != defaultURL {
                            Button("恢复默认") {
                                viewModel.resetBaseURLToDefault()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }

                    if enablesFocus {
                        TextField("https://api.example.com", text: $viewModel.baseURL)
                            .focused($focusedField, equals: .baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.body)
                    } else {
                        TextField("https://api.example.com", text: $viewModel.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.body)
                    }

                    if let error = viewModel.baseURLValidationError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Model ID")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    if enablesFocus {
                        TextField("例如 gpt-4o", text: $viewModel.modelID)
                            .focused($focusedField, equals: .modelID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                    } else {
                        TextField("例如 gpt-4o", text: $viewModel.modelID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                    }

                    if let error = viewModel.modelIDValidationError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("服务端点与模型")
            } footer: {
                Text("Base URL 必须使用 HTTPS 协议且不得包含鉴权信息或查询参数。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // MARK: - API Key 凭证管理
            Section {
                if viewModel.hasSavedAPIKey {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("系统钥匙串中已安全保存 API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if viewModel.isAPIKeyVisible {
                            if enablesFocus {
                                TextField(
                                    viewModel.hasSavedAPIKey ? "输入新 Key 以替换现有密钥" : "输入 API Key",
                                    text: $viewModel.apiKeyInput
                                )
                                .focused($focusedField, equals: .apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.body)
                            } else {
                                TextField(
                                    viewModel.hasSavedAPIKey ? "输入新 Key 以替换现有密钥" : "输入 API Key",
                                    text: $viewModel.apiKeyInput
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.body)
                            }
                        } else {
                            if enablesFocus {
                                SecureField(
                                    viewModel.hasSavedAPIKey ? "输入新 Key 以替换现有密钥" : "输入 API Key",
                                    text: $viewModel.apiKeyInput
                                )
                                .focused($focusedField, equals: .apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.body)
                            } else {
                                SecureField(
                                    viewModel.hasSavedAPIKey ? "输入新 Key 以替换现有密钥" : "输入 API Key",
                                    text: $viewModel.apiKeyInput
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.body)
                            }
                        }

                        Button {
                            viewModel.isAPIKeyVisible.toggle()
                        } label: {
                            Image(systemName: viewModel.isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 24, minHeight: 24)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(viewModel.isAPIKeyVisible ? "隐藏 API Key" : "显示 API Key")
                    }

                    if let error = viewModel.apiKeyValidationError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("身份凭证 (API Key)")
            } footer: {
                Text("API Key 仅保存在本机系统钥匙串中（kSecAttrAccessibleWhenUnlockedThisDeviceOnly），严禁写入明文持久化或同步备份。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // MARK: - 保存操作
            Section {
                Button {
                    handleSave()
                } label: {
                    HStack {
                        Spacer()
                        Text("保存配置")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                        Spacer()
                    }
                }
            }

            // MARK: - 破坏性清除操作（系统二次确认保护）
            if viewModel.hasSavedAPIKey {
                Section {
                    Button(role: .destructive) {
                        handleClearButtonTapped()
                    } label: {
                        HStack {
                            Spacer()
                            Text("清除已保存的 API Key")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle("API 配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    handleSave()
                }
                .fontWeight(.semibold)
            }
        }
        .modifier(ClearConfirmationDialogModifier(
            isPresented: $viewModel.showClearConfirmation,
            onConfirm: { performConfirmClear() },
            onCancel: { performCancelClear() },
            isEnabled: enablesFocus
        ))
    }

    private func handleSave() {
        if let errorField = viewModel.validate() {
            if enablesFocus {
                focusedField = errorField
            }
        } else {
            if viewModel.save() {
                dismiss()
            }
        }
    }

    // MARK: - 破坏性清除按钮交互方法（供 UI 回调与自动化测试精确验证）

    /// 点击“清除已保存的 API Key”按钮，调出系统确认对话框（不执行删除）
    public func handleClearButtonTapped() {
        viewModel.showClearConfirmation = true
    }

    /// 用户在确认对话框中点击“清除 API Key”回调（唯一执行删除的入口）
    public func performConfirmClear() {
        viewModel.clearAPIKey()
        viewModel.showClearConfirmation = false
    }

    /// 用户在确认对话框中点击“取消”或点击外部关闭回调（绝对不执行删除）
    public func performCancelClear() {
        viewModel.showClearConfirmation = false
    }
}

private struct ClearConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .confirmationDialog(
                    "确定要清除已保存的 API Key 吗？",
                    isPresented: $isPresented,
                    titleVisibility: .visible
                ) {
                    Button("清除 API Key", role: .destructive) {
                        onConfirm()
                    }
                    Button("取消", role: .cancel) {
                        onCancel()
                    }
                } message: {
                    Text("清除后将无法发起该服务的翻译请求，需重新录入有效密钥。")
                }
        } else {
            content
        }
    }
}
