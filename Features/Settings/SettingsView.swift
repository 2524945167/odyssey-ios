import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("API 配置") {
                    SettingsRow(title: "API 格式", status: "后续轮次实现")
                    SettingsRow(title: "Base URL", status: "后续轮次实现")
                    SettingsRow(title: "API Key", status: "后续轮次实现")
                    SettingsRow(title: "Model ID", status: "后续轮次实现")
                    SettingsRow(title: "测试连接", status: "后续轮次实现")
                }

                Section("翻译设置") {
                    SettingsRow(title: "术语表", status: "后续轮次实现")
                    SettingsRow(title: "额外要求", status: "后续轮次实现")
                }

                Section("隐私与诊断") {
                    SettingsRow(title: "诊断信息", status: "后续轮次实现")
                    SettingsRow(title: "清除本机设置", status: "后续轮次实现")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let status: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
