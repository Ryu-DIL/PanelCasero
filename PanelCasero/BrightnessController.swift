import SwiftUI
import UIKit

/// Valores del brillo automático.
enum BrightnessConfig {
    static let minLevel: CGFloat = 0.0          // mínimo absoluto de iOS
    static let motionLevel: CGFloat = 0.4       // al detectar movimiento
    static let maxLevel: CGFloat = 1.0          // al tocar la pantalla
    static let idleSeconds: TimeInterval = 60   // sin movimiento -> mínimo
    static let touchSeconds: TimeInterval = 20  // tras tocar, tiempo en máximo
    /// Tras cambiar el brillo, la cámara se ignora este rato (la imagen cambia por la propia pantalla).
    static let settleSeconds: TimeInterval = 4
}

enum BrightnessReason: String {
    case touch, motion, idle
}

/// Lo que la interfaz necesita saber del brillo. Solo se publica cuando algo cambia de verdad.
final class DimState: ObservableObject {
    static let shared = DimState()

    /// Negro semitransparente por encima de toda la interfaz. Sirve para oscurecer MÁS que
    /// el mínimo de la pantalla y para compensar si iOS cambia el brillo por su cuenta.
    @Published private(set) var overlay: Double = 0
    @Published private(set) var target: Double = 1
    @Published private(set) var actual: Double = 1
    @Published private(set) var reason: BrightnessReason = .touch
    /// true si iOS está cambiando el brillo por su cuenta (normalmente: brillo automático).
    @Published private(set) var systemOverride = false

    fileprivate func update(overlay: Double, target: Double, actual: Double,
                            reason: BrightnessReason, systemOverride: Bool) {
        let q = { (x: Double) in (x * 100).rounded() / 100 }
        if self.overlay != q(overlay) { self.overlay = q(overlay) }
        if self.target != q(target) { self.target = q(target) }
        if self.actual != q(actual) { self.actual = q(actual) }
        if self.reason != reason { self.reason = reason }
        if self.systemOverride != systemOverride { self.systemOverride = systemOverride }
    }
}

/// Decide el brillo de la pantalla:
///  - tocar la pantalla -> máximo durante 20 s
///  - movimiento detectado -> 40 % mientras haya movimiento en el último minuto
///  - sin movimiento durante 1 minuto -> mínimo (más una capa de oscurecimiento por software)
final class BrightnessController {
    static let shared = BrightnessController()

    /// Con la alarma armada, el movimiento no sube el brillo (para no avisar al intruso).
    /// Solo se toca desde el hilo principal.
    var motionRaisesBrightness = true

    /// Oscurecimiento extra en reposo (0...0.8). Solo desde el hilo principal.
    var idleOverlay: Double = 0.4

    private var lastMotion: Date = .distantPast
    private var lastTouch: Date = Date()
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var currentLevel: CGFloat = -1
    private var levelSince = Date()
    private var timer: Timer?

    private init() {}

    /// Empieza a controlar el brillo (se puede llamar varias veces).
    func start() {
        guard timer == nil else { return }
        originalBrightness = UIScreen.main.brightness
        currentLevel = -1
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    /// Deja de controlar el brillo y devuelve el que tenía el iPhone antes.
    func stop() {
        timer?.invalidate()
        timer = nil
        if currentLevel >= 0 {
            UIScreen.main.brightness = originalBrightness
        }
        currentLevel = -1
    }

    /// Hay que llamarlo cada vez que se toca la pantalla.
    func touched() {
        runOnMain {
            let now = Date()
            // Mientras se arrastra el dedo no hace falta recalcular en cada movimiento.
            if now.timeIntervalSince(self.lastTouch) < 0.2 && self.currentLevel == BrightnessConfig.maxLevel {
                return
            }
            self.lastTouch = now
            self.tick()
        }
    }

    /// Lo llamará el detector de movimiento cuando vea movimiento.
    func motionDetected() {
        runOnMain {
            guard self.motionRaisesBrightness else { return }
            self.lastMotion = Date()
            self.tick()
        }
    }

    // MARK: - Interno

    private func target(now: Date) -> (level: CGFloat, reason: BrightnessReason) {
        if now.timeIntervalSince(lastTouch) < BrightnessConfig.touchSeconds {
            return (BrightnessConfig.maxLevel, .touch)
        }
        if now.timeIntervalSince(lastMotion) < BrightnessConfig.idleSeconds {
            return (BrightnessConfig.motionLevel, .motion)
        }
        return (BrightnessConfig.minLevel, .idle)
    }

    private func tick() {
        guard timer != nil else { return }
        let now = Date()
        let goal = target(now: now)

        if goal.level != currentLevel {
            currentLevel = goal.level
            levelSince = now
            // La pantalla ilumina la habitación: la cámara debe ignorar este cambio.
            MotionGuard.shared.suppress(for: BrightnessConfig.settleSeconds)
            UIScreen.main.brightness = goal.level
        }

        // ¿Respeta iOS el brillo pedido? Con el brillo automático activado, no.
        let actual = UIScreen.main.brightness
        let settled = now.timeIntervalSince(levelSince) > 3
        let overridden = settled && abs(actual - currentLevel) > 0.08

        var overlay = 0.0
        if goal.reason == .idle {
            overlay = idleOverlay + (overridden ? 0.2 : 0)
        }
        DimState.shared.update(overlay: min(overlay, 0.85), target: Double(currentLevel),
                               actual: Double(actual), reason: goal.reason, systemOverride: overridden)
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

/// Observa todos los toques de la ventana (también los de las ventanas
/// emergentes) sin interferir con ellos: no cancela ni retrasa ningún toque.
final class TouchWatcher: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private static var installed = false

    /// Se engancha a la ventana principal (se reintenta hasta que exista).
    static func install() {
        guard !installed else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        guard let window = window else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { install() }
            return
        }
        window.addGestureRecognizer(TouchWatcher(target: nil, action: nil))
        installed = true
    }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        BrightnessController.shared.touched()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        BrightnessController.shared.touched()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }
}
