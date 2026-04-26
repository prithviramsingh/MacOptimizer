import SwiftUI

struct DSCard<Content: View>: View {
    @Environment(\.themeColors) private var colors
    let padding: CGFloat
    let hoverable: Bool
    let inverted: Bool
    let content: () -> Content

    @State private var isHovered = false

    init(
        padding: CGFloat = 20,
        hoverable: Bool = false,
        inverted: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.hoverable = hoverable
        self.inverted = inverted
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background {
                if inverted {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(colors.ink)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(Color.white.opacity(0.30))
                        )
                }
            }
            .foregroundStyle(inverted ? colors.paper : colors.ink)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(
                        inverted ? Color.white.opacity(0.08) : Color.white.opacity(0.65),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: .black.opacity(hoverable && isHovered ? 0.14 : 0.07),
                radius: hoverable && isHovered ? 18 : 10,
                x: 0, y: hoverable && isHovered ? 6 : 3
            )
            .scaleEffect(hoverable && isHovered ? 1.004 : 1)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.18), value: isHovered)
    }
}
