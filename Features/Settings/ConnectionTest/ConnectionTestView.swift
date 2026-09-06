import SwiftUI

public struct ConnectionTestView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.enablesFocus) private var enablesFocus
    @FocusState private var isLimitFocused: Bool
    @State private var viewModel: ConnectionTestViewModel

    public init(store: APIConfigurationStore) {
        _viewModel = State(initialValue: ConnectionTestViewModel(store: store))
    }

    public init(viewModel: ConnectionTestViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Form {
            Section("已保存配置") {
                if let configuration = viewModel.configuration {
                    LabeledContent("协议", value: configuration.apiFormat.displayName)
                    LabeledContent("Model ID", value: configuration.modelID)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("实际请求地址")
                        Text(viewModel.endpointText ?? "服务地址无效")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .privacySensitive()
                    }
                    LabeledContent("API Key", value: viewModel.hasSavedKey ? "已安全保存" : "未保存")
                } else {
                    Text("请先返回 API 配置页面，保存服务地址、Model ID 与 API Key。")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("连接测试输出上限（tokens）")
                    if enablesFocus {
                        limitField.focused($isLimitFocused)
                    } else {
                        limitField
                    }
                    if let error = viewModel.outputLimitError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                Button("恢复为 256") { viewModel.resetOutputLimit() }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isTesting)
            } header: {
                Text("测试选项")
            } footer: {
                Text("默认 256，开始测试时保存在本机，仅用于连接测试。请输入正整数；服务商可能有自己的限制。提高上限可能增加费用，推理也可能占用额度。")
            }

            Section {
                if viewModel.isTesting {
                    HStack {
                        ProgressView()
                        Text("正在测试…")
                    }
                    Button("取消测试", role: .cancel) { viewModel.cancel() }
                        .buttonStyle(.borderless)
                } else {
                    Button("开始测试") {
                        if enablesFocus { isLimitFocused = false }
                        viewModel.start()
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canStart)
                    .accessibilityIdentifier("connectionTest.start")
                }
            } footer: {
                Text("仅在点击后使用已保存配置发送一次固定短句“Reply with OK.”，可能产生 API 费用。不发送首页原文；30 秒超时，不自动重试或切换协议。离开页面或进入后台会取消本地请求，但不保证服务端停止计费。")
            }

            resultSection
        }
        .navigationTitle("测试连接")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if enablesFocus {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isLimitFocused = false }
                }
            }
        }
        .onAppear { viewModel.refreshConfiguration() }
        .onDisappear { viewModel.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.cancel() }
        }
    }

    private var limitField: some View {
        @Bindable var model = viewModel
        return TextField("256", text: $model.outputLimitText)
            .keyboardType(.numberPad)
            .disabled(viewModel.isTesting)
            .accessibilityLabel("连接测试输出上限，tokens")
            .accessibilityIdentifier("connectionTest.outputLimit")
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.state {
        case .idle, .running: EmptyView()
        case .finished(let result):
            Section("测试结果") {
                Label(result.outcome.title, systemImage: result.outcome == .success ? "checkmark.circle" : "exclamationmark.circle")
                    .foregroundStyle(result.outcome == .success ? Color.green : Color.orange)
                Text(result.outcome.detail).font(.subheadline)
                LabeledContent("耗时", value: result.elapsedSeconds.formatted(.number.precision(.fractionLength(2))) + " 秒")
            }
        case .failed(let error):
            Section("测试结果") {
                Label("测试未成功", systemImage: "exclamationmark.circle").foregroundStyle(.red)
                Text(error.errorDescription ?? "测试未成功").font(.subheadline)
            }
        case .cancelled:
            Section("测试结果") {
                Text(ConnectionTestError.cancelled.errorDescription ?? "已取消")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
