import SwiftUI

enum DSButtonVariant {
    case primary, solid, ghost, danger, link
}

struct DSButtonStyle: ButtonStyle {
    @Environment(\.themeColors) private var colors
    let variant: DSButtonVariant
    let small: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(small ? AppFont.buttonSmUI : AppFont.buttonUI)
            .foregroundStyle(fg)
            .padding(.horizontal, small ? 10 : 14)
            .padding(.vertical,   small ?  5 :  7)
            .background(bg(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private var fg: Color {
        switch variant {
        case .primary: return .white
        case .solid:   return colors.paper
        case .ghost:   return colors.ink70
        case .danger:  return .white
        case .link:    return colors.accent
        }
    }

    private func bg(pressed: Bool) -> Color {
        let darken = pressed ? 0.85 : 1.0
        switch variant {
        case .primary: return colors.accent.opacity(darken)
        case .solid:   return colors.ink.opacity(darken)
        case .ghost:   return colors.ink.opacity(pressed ? 0.08 : 0)
        case .danger:  return colors.critical.opacity(darken)
        case .link:    return .clear
        }
    }

    private var border: Color {
        switch variant {
        case .ghost: return colors.ink15
        case .link:  return .clear
        default:     return .clear
        }
    }
}

struct DSBtn: View {
    let label: String
    let variant: DSButtonVariant
    let small: Bool
    let action: () -> Void

    init(_ label: String, variant: DSButtonVariant = .primary, small: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.variant = variant
        self.small = small
        self.action = action
    }

    var body: some View {
        Button(label, action: action)
            .buttonStyle(DSButtonStyle(variant: variant, small: small))
    }
}
