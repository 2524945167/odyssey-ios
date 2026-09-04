import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("API 配置") {
                    NavigationLink {
                        PlaceholderDetailView(title: "API 格式", icon: "slider.horizontal.3")
                    } label: {
                        Label("API 格式", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "Base URL", icon: "link")
                    } label: {
                        Label("Base URL", systemImage: "link")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "API Key", icon: "key")
                    } label: {
                        Label("API Key", systemImage: "key")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "Model ID", icon: "cpu")
                    } label: {
                        Label("Model ID", systemImage: "cpu")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "测试连接", icon: "antenna.radiowaves.left.and.right")
                    } label: {
                        Label("测试连接", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                Section("翻译设置") {
                    NavigationLink {
                        PlaceholderDetailView(title: "术语表", icon: "character.book.closed")
                    } label: {
                        Label("术语表", systemImage: "character.book.closed")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "额外要求", icon: "text.badge.plus")
                    } label: {
                        Label("额外要求", systemImage: "text.badge.plus")
                    }
                }

                Section("隐私与诊断") {
                    NavigationLink {
                        PlaceholderDetailView(title: "诊断信息", icon: "stethoscope")
                    } label: {
                        Label("诊断信息", systemImage: "stethoscope")
                    }

                    NavigationLink {
                        PlaceholderDetailView(title: "清除本机设置", icon: "trash")
                    } label: {
                        Label("清除本机设置", systemImage: "trash")
                    }
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

public struct PlaceholderDetailView: View {
    public let title: String
    public let icon: String

    public init(title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.blue)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text("将在后续轮次实现")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
