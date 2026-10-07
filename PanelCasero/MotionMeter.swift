import Foundation

/// Indicador de movimiento para Ajustes. Está aparte de la cámara a propósito: se actualiza
/// varias veces por segundo y solo debe redibujar la pantalla de Ajustes, no toda la interfaz.
final class MotionMeter: ObservableObject {
    static let shared = MotionMeter()

    @Published private(set) var score: Double = 0

    private var lastPublish = Date.distantPast

    /// Se llama desde el hilo principal.
    func set(_ value: Double) {
        let rounded = (value * 20).rounded() / 20          // pasos de 5 %
        let now = Date()
        guard rounded != score, now.timeIntervalSince(lastPublish) >= 0.3 || rounded == 0 else { return }
        lastPublish = now
        score = rounded
    }
}
