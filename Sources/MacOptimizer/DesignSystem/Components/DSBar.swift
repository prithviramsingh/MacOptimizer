import SwiftUI

struct DSBar: View {
    @Environment(\.themeColors) private var colors

    let value: Double
    let maxValue: Double
    let height: CGFloat
    let hue: Color?

    init(value: Double, maxValue: Double = 100, height: CGFloat = 4, hue: Color? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.height = height
        self.hue = hue
    }

    private var fraction: Double {
        maxValue > 0 ? min(max(value / maxValue, 0), 1) : 0
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(colors.ink8)
            Capsule()
                .fill(hue ?? colors.accent)
                .scaleEffect(x: fraction, y: 1.0, anchor: .leading)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fraction)
        }
        .frame(height: height)
        .drawingGroup()
    }
}
