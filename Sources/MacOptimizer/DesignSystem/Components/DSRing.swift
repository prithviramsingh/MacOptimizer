import SwiftUI

struct DSRing: View {
    @Environment(\.themeColors) private var colors

    let value: Double      // 0-100
    let size: CGFloat
    let strokeWidth: CGFloat
    let label: String?
    let sub: String?
    let hue: Color?

    init(
        value: Double,
        size: CGFloat = 112,
        strokeWidth: CGFloat = 8,
        label: String? = nil,
        sub: String? = nil,
        hue: Color? = nil
    ) {
        self.value = value
        self.size = size
        self.strokeWidth = strokeWidth
        self.label = label
        self.sub = sub
        self.hue = hue
    }

    private var fraction: Double { min(max(value / 100, 0), 1) }
    private var fill: Color { hue ?? colors.accent }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(colors.ink8, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Fill arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(fill, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)

            // Center label — serif hero numeric
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(Int(value.rounded())))
                        .font(.system(size: size * 0.30, weight: .regular, design: .serif))
                    Text("%")
                        .font(.system(size: size * 0.13, weight: .regular, design: .serif))
                        .opacity(0.5)
                }
                if let label {
                    Text(label)
                        .font(AppFont.eyebrowUI)
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .opacity(0.45)
                        .padding(.top, 1)
                }
                if let sub {
                    Text(sub)
                        .font(AppFont.captionUI)
                        .opacity(0.45)
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}
