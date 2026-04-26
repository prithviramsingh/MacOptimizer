import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private var storedTheme: String = AppTheme.paper.rawValue

    @Published var currentTheme: AppTheme = .paper {
        didSet { storedTheme = currentTheme.rawValue }
    }

    var colors: ThemeColors {
        currentTheme == .paper ? .paper : .graphite
    }

    var colorScheme: ColorScheme? {
        currentTheme == .graphite ? .dark : .light
    }

    init() {
        currentTheme = AppTheme(rawValue: storedTheme) ?? .paper
    }

    func toggle() {
        currentTheme = (currentTheme == .paper) ? .graphite : .paper
    }
}
