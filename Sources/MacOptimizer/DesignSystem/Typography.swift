import SwiftUI

enum AppFont {
    // MARK: - Hero (New York serif)
    static func hero(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // MARK: - UI (SF Pro)
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Mono (SF Mono)
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Named presets
    static let heroLarge   = hero(48)
    static let heroMedium  = hero(32)
    static let heroSmall   = hero(18)

    static let bodyUI      = ui(13)
    static let captionUI   = ui(11, weight: .medium)
    static let eyebrowUI   = ui(10, weight: .bold)
    static let navUI       = ui(13, weight: .semibold)
    static let buttonUI    = ui(13, weight: .semibold)
    static let buttonSmUI  = ui(12, weight: .semibold)

    static let monoSmall   = mono(11)
    static let monoCaption = mono(10.5)
    static let monoBody    = mono(13)
}

// MARK: - Eyebrow modifier

struct EyebrowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFont.eyebrowUI)
            .tracking(1.4)
            .textCase(.uppercase)
    }
}

extension View {
    func eyebrowStyle() -> some View {
        modifier(EyebrowModifier())
    }
}
