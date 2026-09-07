import SwiftUI

public struct TranslationOptionsView: View {
    @State private var viewModel: TranslationOptionsViewModel
    private let configuration: APIConfiguration?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case output, timeout }

    public init(viewModel: TranslationOptionsViewModel = TranslationOptionsViewModel(), configuration: APIConfiguration? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.configuration = configuration
    }

    public var body: some View {
        @Bindable var model = viewModel
        Form {
            Section {
                if TranslationThinkingPolicy.supports(configuration) {
                    Toggle("深度思考", isOn: $model.thinkingEnabled)
                        .accessibilityIdentifier("translationOptions.thinking")
                } else {
                    LabeledContent("深度思考", value: "跟随模型默认")
                        .accessibilityIdentifier("translationOptions.thinking.unmanaged")
                }
            } footer: {
                if TranslationThinkingPolicy.supports(configuration) {
                    Text("默认关闭。开启后模型可进行额外推理，可能增加等待和消耗。保存后用于下一次翻译，译文中不显示思考过程。")
                } else {
                    Text("当前接口或模型没有已确认的通用思考开关，因此不额外发送控制参数。不代表思考已关闭，也不限制基础翻译功能。")
                }
            }

            Section {
                TextField("8192", text: $model.outputLimitText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .output)
                    .accessibilityLabel("翻译输出上限，tokens")
                    .accessibilityIdentifier("translationOptions.outputLimit")
                if let error = viewModel.outputLimitError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("输出上限（tokens）")
            } footer: {
                Text("默认 8192，可自定义。它不是字数或总费用上限；部分模型的推理也占用额度。服务商可能有自己的限制，应用不会自动改值或重试。")
            }

            Section {
                TextField("60", text: $model.idleTimeoutText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .timeout)
                    .accessibilityLabel("无数据超时，秒")
                    .accessibilityIdentifier("translationOptions.idleTimeout")
                if let error = viewModel.idleTimeoutError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                LabeledContent("单次请求总时长上限", value: "5 分钟")
            } header: {
                Text("无数据超时（秒）")
            } footer: {
                Text("默认连续 60 秒未收到数据时超时；收到数据后重新计时。即使此处设得更长，单次请求仍最多持续 5 分钟。超时保留已有译文，不自动重试。")
            }

            Section {
                Button("保存") {
                    focusedField = nil
                    viewModel.save()
                }
                .accessibilityIdentifier("translationOptions.save")
                Button("恢复默认值") { viewModel.restoreDefaults() }
                    .accessibilityIdentifier("translationOptions.restore")
                if viewModel.didSave {
                    Label("已保存", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("点击保存后用于下一次翻译；不会改变正在进行的请求或连接测试设置。恢复默认值后也需要保存。")
            }
        }
        .navigationTitle("翻译参数")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
    }
}
