import SwiftUI

enum ChipTone {
    case neutral, accent, good, warn, danger
}

struct DSChip: View {
    @Environment(\.themeColors) private var colors

    let text: String
    let tone: ChipTone

    init(_ text: String, tone: ChipTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    private var bg: Color {
        switch tone {
        case .neutral: return colors.ink10
        case .accent:  return colors.accent10
        case .good:    return colors.good10
        case .warn:    return colors.warning.opacity(0.15)
        case .danger:  return colors.critical.opacity(0.12)
        }
    }

    private var fg: Color {
        switch tone {
        case .neutral: return colors.ink70
        case .accent:  return colors.accentStrong
        case .good:    return colors.goodStrong
        case .warn:    return colors.warning
        case .danger:  return colors.critical
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.eyebrowUI)
            .tracking(0.6)
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}
