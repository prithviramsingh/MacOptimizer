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
    case light = "Light"
    case dark  = "Dark"
}

// MARK: - Aurora Scene Colors

struct AuroraColors {
    let blob1: Color // top-left
    let blob2: Color // top-right
    let blob3: Color // bottom-right
    let blob4: Color // bottom-left
    let base1: Color
    let base2: Color
}

// MARK: - Theme Colors

struct ThemeColors {
    let paper:       Color
    let surface:     Color
    let surfaceDeep: Color
    let sidebar:     Color
    let ink:         Color

    // Ink opacity ramp
    var ink5:  Color { ink.opacity(0.05) }
    var ink8:  Color { ink.opacity(0.08) }
    var ink10: Color { ink.opacity(0.10) }
    var ink15: Color { ink.opacity(0.15) }
    var ink20: Color { ink.opacity(0.20) }
    var ink30: Color { ink.opacity(0.30) }
    var ink40: Color { ink.opacity(0.40) }
    var ink50: Color { ink.opacity(0.50) }
    var ink60: Color { ink.opacity(0.60) }
    var ink70: Color { ink.opacity(0.74) }

    // Accent — oklch(64% 0.18 255) ≈ perceptual blue
    let accent:       Color
    let accentStrong: Color
    var accent5:  Color { accent.opacity(0.05) }
    var accent10: Color { accent.opacity(0.12) }
    var accent20: Color { accent.opacity(0.22) }

    // Good — oklch(60% 0.12 160) ≈ muted green
    let good:       Color
    let goodStrong: Color
    var good10: Color { good.opacity(0.12) }
    var good20: Color { good.opacity(0.22) }

    // Semantic severity
    let critical: Color
    let warning:  Color

    // Aurora backdrop
    let aurora: AuroraColors

    // MARK: - Palettes

    static let light = ThemeColors(
        paper:       Color(hex: 0xF6F4EE),
        surface:     Color.white.opacity(0.55),
        surfaceDeep: Color.white.opacity(0.38),
        sidebar:     Color.white.opacity(0.45),
        ink:         Color(hex: 0x1A1A1C),
        accent:      Color(hex: 0x4B8EF7),
        accentStrong: Color(hex: 0x2468D8),
        good:        Color(hex: 0x3DAD7E),
        goodStrong:  Color(hex: 0x1F8059),
        critical:    Color(hex: 0xE03B1A),
        warning:     Color(hex: 0xD97706),
        aurora: AuroraColors(
            blob1: Color(hex: 0xB9D4FF),
            blob2: Color(hex: 0xF4C8E8),
            blob3: Color(hex: 0xFFD9B3),
            blob4: Color(hex: 0xC5E9D9),
            base1: Color(hex: 0xEEF0F6),
            base2: Color(hex: 0xF5EEE6)
        )
    )

    static let dark = ThemeColors(
        paper:       Color(hex: 0x1A1B1C),
        surface:     Color(hex: 0x282A30).opacity(0.50),
        surfaceDeep: Color(hex: 0x282A30).opacity(0.30),
        sidebar:     Color(hex: 0x1C1E22).opacity(0.55),
        ink:         Color(hex: 0xF0EBE2),
        accent:      Color(hex: 0x5B9DF8),
        accentStrong: Color(hex: 0x3B7DE0),
        good:        Color(hex: 0x4ABF8E),
        goodStrong:  Color(hex: 0x2E9A70),
        critical:    Color(hex: 0xFF5540),
        warning:     Color(hex: 0xF59E0B),
        aurora: AuroraColors(
            blob1: Color(hex: 0x16365E),
            blob2: Color(hex: 0x4A1F44),
            blob3: Color(hex: 0x5E3A1D),
            blob4: Color(hex: 0x1F4A3A),
            base1: Color(hex: 0x13141A),
            base2: Color(hex: 0x1A1410)
        )
    )
}

// MARK: - Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ThemeColors.light
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
