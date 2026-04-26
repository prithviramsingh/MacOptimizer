import SwiftUI

struct DSToggleStyle: ToggleStyle {
    @Environment(\.themeColors) private var colors

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            pill(isOn: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }

    private func pill(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? colors.accent : colors.ink15)
                .frame(width: 34, height: 20)
                .animation(.easeInOut(duration: 0.16), value: isOn)

            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                .frame(width: 16, height: 16)
                .padding(2)
                .animation(.spring(response: 0.18, dampingFraction: 0.55), value: isOn)
        }
        .frame(width: 34, height: 20)
    }
}

// Convenience view
struct DSToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(DSToggleStyle())
    }
}
