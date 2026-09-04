import SwiftUI

/// API 配置详情表单视图
/// 提供格式选择、端点输入、模型配置与钥匙串凭证管理
public struct APIConfigurationView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State public var viewModel: APIConfigurationViewModel
    @FocusState private var focusedField: APIFormField?

    @MainActor
    public init(viewModel: APIConfigurationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Form {
            // MARK: - API 格式选择
            Section {
                Picker("格式类型", selection: $viewModel.apiFormat) {
                    ForEach(APIFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.navigationLink)
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

                    TextField("https://api.example.com", text: $viewModel.baseURL)
                        .focused($focusedField, equals: .baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.body)

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
                        if viewModel.modelID != "gpt-4o" {
                            Button("恢复默认") {
                                viewModel.resetModelIDToDefault()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }

                    TextField("例如 gpt-4o", text: $viewModel.modelID)
                        .focused($focusedField, equals: .modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body)

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
                            TextField(
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
                            .focused($focusedField, equals: .apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
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

            // MARK: - 破坏性清除操作
            if viewModel.hasSavedAPIKey {
                Section {
                    Button(role: .destructive) {
                        viewModel.showClearConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("清除已保存的 API Key")
                            Spacer()
                        }
                    }
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
        .confirmationDialog(
            "确定要清除已保存的 API Key 吗？",
            isPresented: $viewModel.showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除 API Key", role: .destructive) {
                viewModel.clearAPIKey()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清除后将无法发起该服务的翻译请求，需重新录入有效密钥。")
        }
        .alert(
            "保存结果",
            isPresented: Binding(
                get: { viewModel.saveSuccessMessage != nil },
                set: { if !$0 { viewModel.saveSuccessMessage = nil } }
            )
        ) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text(viewModel.saveSuccessMessage ?? "")
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 进入后台或非活跃状态时，自动防窥隐藏明文
            if newPhase != .active {
                viewModel.hideAPIKey()
            }
        }
    }

    private func handleSave() {
        if let errorField = viewModel.validate() {
            focusedField = errorField
        } else {
            _ = viewModel.save()
        }
    }
}
