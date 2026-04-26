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

    private var bg: Color { inverted ? colors.ink : colors.surface }
    private var fg: Color { inverted ? colors.paper : colors.ink }
    private var border: Color { inverted ? colors.paper.opacity(0.10) : colors.ink8 }

    var body: some View {
        content()
            .padding(padding)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(hoverable && isHovered ? 0.08 : 0),
                radius: 12, x: 0, y: 4
            )
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.16), value: isHovered)
    }
}
