import SwiftUI

/// Tarjeta con fondo redondeado que usan todos los bloques de la pantalla.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}
