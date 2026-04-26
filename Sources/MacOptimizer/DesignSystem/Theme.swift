import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case paper    = "Paper"
    case graphite = "Graphite"
}

// MARK: - Theme Colors

struct ThemeColors {
    let paper:       Color
    let surface:     Color
    let surfaceDeep: Color
    let sidebar:     Color
    let ink:         Color

    // Ink opacity ramp
    var ink5:  Color { ink.opacity(0.04) }
    var ink8:  Color { ink.opacity(0.08) }
    var ink10: Color { ink.opacity(0.10) }
    var ink15: Color { ink.opacity(0.15) }
    var ink20: Color { ink.opacity(0.20) }
    var ink30: Color { ink.opacity(0.30) }
    var ink40: Color { ink.opacity(0.40) }
    var ink50: Color { ink.opacity(0.50) }
    var ink60: Color { ink.opacity(0.60) }
    var ink70: Color { ink.opacity(0.74) }

    // Accent: burnt orange (oklch(62% 0.17 35) ≈ #C4613A)
    let accent:       Color
    let accentStrong: Color
    var accent5:  Color { accent.opacity(0.05) }
    var accent10: Color { accent.opacity(0.12) }
    var accent20: Color { accent.opacity(0.22) }

    // Good: moss green (oklch(55% 0.09 150) ≈ #4E8A5C)
    let good:       Color
    let goodStrong: Color
    var good10: Color { good.opacity(0.12) }
    var good20: Color { good.opacity(0.22) }

    // Semantic severity
    let critical: Color  // red
    let warning:  Color  // amber

    // MARK: - Palettes

    static let paper = ThemeColors(
        paper:       Color(hex: 0xF4EFE7),
        surface:     Color(hex: 0xFBF8F2),
        surfaceDeep: Color(hex: 0xEEE8DD),
        sidebar:     Color(hex: 0xEDE7DB),
        ink:         Color(hex: 0x1A1A1C),
        accent:      Color(hex: 0xC4613A),
        accentStrong: Color(hex: 0x9A4422),
        good:        Color(hex: 0x4E8A5C),
        goodStrong:  Color(hex: 0x2D6B3D),
        critical:    Color(hex: 0xC0392B),
        warning:     Color(hex: 0xC49A2B)
    )

    static let graphite = ThemeColors(
        paper:       Color(hex: 0x1A1B1C),
        surface:     Color(hex: 0x232426),
        surfaceDeep: Color(hex: 0x1E1F21),
        sidebar:     Color(hex: 0x17181A),
        ink:         Color(hex: 0xF0EBE2),
        accent:      Color(hex: 0xD4714A),
        accentStrong: Color(hex: 0xB5532E),
        good:        Color(hex: 0x5E9A6C),
        goodStrong:  Color(hex: 0x4A8058),
        critical:    Color(hex: 0xE05040),
        warning:     Color(hex: 0xD4AA3B)
    )
}

// MARK: - Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.paper
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
