import SwiftUI

struct DSEyebrow<Trailing: View>: View {
    @Environment(\.themeColors) private var colors

    let text: String
    let trailing: Trailing

    init(_ text: String, @ViewBuilder trailing: () -> Trailing) {
        self.text = text
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(text)
                .eyebrowStyle()
                .foregroundStyle(colors.ink50)
            Spacer()
            trailing
        }
    }
}

extension DSEyebrow where Trailing == EmptyView {
    init(_ text: String) {
        self.text = text
        self.trailing = EmptyView()
    }
}
