import SwiftUI

public struct ContentView: View {
    @MainActor
    public init() {}

    @MainActor
    public var body: some View {
        TranslationView()
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
