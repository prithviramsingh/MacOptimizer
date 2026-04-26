import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private var storedTheme: String = AppTheme.light.rawValue

    @Published var currentTheme: AppTheme = .light {
        didSet { storedTheme = currentTheme.rawValue }
    }

    var colors: ThemeColors {
        currentTheme == .light ? .light : .dark
    }

    var colorScheme: ColorScheme? {
        currentTheme == .dark ? .dark : .light
    }

    init() {
        currentTheme = AppTheme(rawValue: storedTheme) ?? .light
    }

    func toggle() {
        currentTheme = (currentTheme == .light) ? .dark : .light
    }
}
