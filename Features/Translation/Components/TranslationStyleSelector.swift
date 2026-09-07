import SwiftUI

public struct TranslationStyleSelector: View {
    @Bindable var viewModel: TranslationViewModel
    let onSelect: () -> Void

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(TranslationStyle.allCases) { style in
                    let selected = viewModel.preferences.styles.selectedStyle == style
                    Button {
                        onSelect()
                        viewModel.selectStyle(style)
                    } label: {
                        Text(style.title)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.blue : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(selected ? .blue.opacity(0.12) : .clear), in: Capsule())
                    .accessibilityLabel(style.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("translationStyle.\(style.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .disabled(viewModel.isTranslating)
        .accessibilityHint("左右滑动选择风格；翻译进行中暂不可切换")
    }
}
