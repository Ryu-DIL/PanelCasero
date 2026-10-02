import Foundation

/// Avisa al detector de movimiento de que la luz de la habitación acaba de
/// cambiar por causa conocida (por ejemplo, la app encendió una luz o cambió el
/// brillo de la pantalla), para que no lo confunda con una persona.
final class MotionGuard {
    static let shared = MotionGuard()

    private let lock = NSLock()
    private var until = Date.distantPast

    private init() {}

    /// Ignora la cámara durante los próximos `seconds` segundos.
    func suppress(for seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        let end = Date().addingTimeInterval(seconds)
        if end > until { until = end }
    }

    var isSuppressed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return Date() < until
    }
}
