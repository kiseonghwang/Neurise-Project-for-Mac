import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.blue)
            .padding(.vertical, 15)
            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func formFieldStyle() -> some View {
        self
            .padding(15)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}
