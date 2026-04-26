import SwiftUI

struct DSPulseDot: View {
    @Environment(\.themeColors) private var colors
    let color: Color?

    init(color: Color? = nil) { self.color = color }

    @State private var animating = false

    private var fill: Color { color ?? colors.good }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 6, height: 6)
            .scaleEffect(animating ? 1.4 : 1.0)
            .opacity(animating ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
    }
}
