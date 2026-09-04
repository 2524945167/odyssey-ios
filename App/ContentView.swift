import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.circle")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.blue)

            Text("Odyssey")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text("工程初始化成功")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
