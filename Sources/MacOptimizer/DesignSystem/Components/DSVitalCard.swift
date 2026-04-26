import SwiftUI

struct DSVitalCard: View {
    @Environment(\.themeColors) private var colors

    let eyebrow: String
    let hero: String
    let unit: String
    let barValue: Double
    let barMax: Double
    let barHue: Color?
    let footer: String

    init(
        eyebrow: String,
        hero: String,
        unit: String = "",
        barValue: Double,
        barMax: Double = 100,
        barHue: Color? = nil,
        footer: String = ""
    ) {
        self.eyebrow = eyebrow
        self.hero = hero
        self.unit = unit
        self.barValue = barValue
        self.barMax = barMax
        self.barHue = barHue
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow(eyebrow)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(hero)
                    .font(AppFont.heroLarge)
                    .foregroundStyle(colors.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(AppFont.captionUI)
                        .foregroundStyle(colors.ink50)
                }
            }

            DSBar(value: barValue, maxValue: barMax, height: 4, hue: barHue)

            if !footer.isEmpty {
                Text(footer)
                    .font(AppFont.captionUI)
                    .foregroundStyle(colors.ink50)
            }
        }
    }
}
