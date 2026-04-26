import SwiftUI

struct DSSparkline: View {
    @Environment(\.themeColors) private var colors

    let values: [Double]
    let hue: Color?

    init(values: [Double], hue: Color? = nil) {
        self.values = values
        self.hue = hue
    }

    private var stroke: Color { hue ?? colors.accent }
    private var fill: Color   { stroke.opacity(0.12) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts = points(in: CGSize(width: w, height: h))

            ZStack {
                // Filled area
                if pts.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: pts[0].x, y: h))
                        path.addLine(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(fill)
                }

                // Line
                if pts.count > 1 {
                    Path { path in
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(stroke, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                // Trailing dot
                if let last = pts.last {
                    Circle()
                        .fill(stroke)
                        .frame(width: 4, height: 4)
                        .position(last)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let hi = values.max() ?? 1
        let lo = values.min() ?? 0
        let range = max(hi - lo, 1)
        let step = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { i, v in
            let x = CGFloat(i) * step
            let y = size.height - ((v - lo) / range) * size.height * 0.85 - size.height * 0.075
            return CGPoint(x: x, y: y)
        }
    }
}
