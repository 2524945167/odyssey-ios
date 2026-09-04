import SwiftUI

public struct ContentView: View {
    public init() {}

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
