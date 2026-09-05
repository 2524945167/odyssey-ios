import SwiftUI

/// 使用 SwiftUI 原生 Shape 绘制的“指南针化字母 O”。
/// 主体为系统蓝圆环，在右上角 45°（北偏东）位置设计紧凑短小的指南针指针尖角，
/// 视觉上第一眼即识别为大写字母 O，同时兼备指南针方向意象，内部中空无冗余刻度。
public struct CompassLetterOShape: Shape {
    public var strokeWidth: CGFloat
    public var tipLength: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(strokeWidth, tipLength) }
        set {
            strokeWidth = newValue.first
            tipLength = newValue.second
        }
    }

    public init(strokeWidth: CGFloat = 2.2, tipLength: CGFloat = 3.0) {
        self.strokeWidth = strokeWidth
        self.tipLength = tipLength
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        let baseSize = min(rect.width, rect.height)
        guard baseSize > 2 else { return path }

        // 为右上角 45° 尖角预留边距
        let outerRadius = (baseSize - tipLength * 0.72) / 2.0
        guard outerRadius > strokeWidth else { return path }
        let innerRadius = outerRadius - strokeWidth

        // 中心点定于左下侧，使圆环底边与左边贴合 rect 边界
        let center = CGPoint(
            x: rect.minX + outerRadius,
            y: rect.maxY - outerRadius
        )

        // 45° 东北向尖角（屏幕坐标系正 Y 向下，东北向对应 -pi/4）
        let needleAngle: Double = -Double.pi / 4.0
        let baseHalfSpread: Double = 0.28 // 弧度（约 16°）

        let angleStart = needleAngle + baseHalfSpread
        let angleEnd = needleAngle - baseHalfSpread

        let tipPoint = CGPoint(
            x: center.x + (outerRadius + tipLength) * CGFloat(cos(needleAngle)),
            y: center.y + (outerRadius + tipLength) * CGFloat(sin(needleAngle))
        )

        let base2 = CGPoint(
            x: center.x + outerRadius * CGFloat(cos(angleStart)),
            y: center.y + outerRadius * CGFloat(sin(angleStart))
        )

        // 1. 外轮廓：圆环大部分弧线 + 右上角 45° 尖角
        path.move(to: base2)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: Angle(radians: angleStart),
            endAngle: Angle(radians: angleEnd),
            clockwise: false
        )
        path.addLine(to: tipPoint)
        path.addLine(to: base2)
        path.closeSubpath()

        // 2. 内轮廓：内部镂空形成字母 O 的中空圆环
        path.addEllipse(in: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2.0,
            height: innerRadius * 2.0
        ))

        return path
    }
}

/// Odyssey 专用品牌标题组件
/// 将“指南针化的 O”与“dyssey”在同一视觉基线紧凑拼装，
/// 支持浅色/深色模式、Dynamic Type 字体缩放及单一无障碍标签。
public struct OdysseyBrandTitle: View {
    @ScaledMetric(relativeTo: .headline) private var oSize: CGFloat = 16.5
    @ScaledMetric(relativeTo: .headline) private var strokeWidth: CGFloat = 2.2
    @ScaledMetric(relativeTo: .headline) private var tipLength: CGFloat = 3.0
    @ScaledMetric(relativeTo: .headline) private var letterSpacing: CGFloat = -1.5
    @ScaledMetric(relativeTo: .headline) private var baselineOffset: CGFloat = 1.0

    public init() {}

    public var body: some View {
        let offset = baselineOffset
        HStack(alignment: .firstTextBaseline, spacing: letterSpacing) {
            CompassLetterOShape(
                strokeWidth: strokeWidth,
                tipLength: tipLength
            )
            .fill(Color.blue, style: FillStyle(eoFill: true))
            .frame(width: oSize, height: oSize)
            .alignmentGuide(.firstTextBaseline) { d in
                d.height - offset
            }

            Text("dyssey")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Odyssey")
    }
}

#Preview("浅色模式") {
    OdysseyBrandTitle()
        .padding()
        .preferredColorScheme(.light)
}

#Preview("深色模式") {
    OdysseyBrandTitle()
        .padding()
        .preferredColorScheme(.dark)
}
