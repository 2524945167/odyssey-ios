import SwiftUI

public struct TopBrandBar: View {
    public var onOpenSettings: () -> Void
    public var onTapBackground: (() -> Void)?

    public init(
        onOpenSettings: @escaping () -> Void,
        onTapBackground: (() -> Void)? = nil
    ) {
        self.onOpenSettings = onOpenSettings
        self.onTapBackground = onTapBackground
    }

    public var body: some View {
        HStack {
            OdysseyBrandTitle()

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
        .contentShape(Rectangle())
        .onTapGesture {
            onTapBackground?()
        }
    }
}

#Preview {
    TopBrandBar {}
}
