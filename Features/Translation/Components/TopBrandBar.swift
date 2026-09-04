import SwiftUI

public struct TopBrandBar: View {
    public var onOpenSettings: () -> Void

    public init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue)

                Text("Odyssey")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(8)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

#Preview {
    TopBrandBar {}
}
