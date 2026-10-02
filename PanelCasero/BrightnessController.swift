import SwiftUI
import UIKit

/// Valores del brillo automático (más adelante se podrán cambiar desde Ajustes).
enum BrightnessConfig {
    static let minLevel: CGFloat = 0.0        // mínimo absoluto de iOS
    static let motionLevel: CGFloat = 0.4     // al detectar movimiento
    static let maxLevel: CGFloat = 1.0        // al tocar la pantalla
    static let idleSeconds: TimeInterval = 60 // sin movimiento -> mínimo
    static let touchSeconds: TimeInterval = 20 // tras tocar, tiempo en máximo
}

/// Decide el brillo de la pantalla:
///  - tocar la pantalla -> máximo durante 20 s
///  - movimiento detectado -> 40 % mientras haya movimiento en el último minuto
///  - sin movimiento durante 1 minuto -> mínimo
final class BrightnessController {
    static let shared = BrightnessController()

    /// Momento del último cambio de brillo. El detector de movimiento (fase 3)
    /// lo usará para ignorar los fotogramas justo después de un cambio de luz.
    var lastChange: Date {
        changeLock.lock()
        defer { changeLock.unlock() }
        return changedAt
    }

    private let changeLock = NSLock()
    private var changedAt: Date = .distantPast

    private var lastMotion: Date = .distantPast
    private var lastTouch: Date = Date()
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var currentLevel: CGFloat = -1
    private var timer: Timer?

    private init() {}

    /// Empieza a controlar el brillo (se puede llamar varias veces).
    func start() {
        guard timer == nil else { return }
        originalBrightness = UIScreen.main.brightness
        currentLevel = -1
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        update()
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
            self.lastTouch = Date()
            self.update()
        }
    }

    /// Lo llamará el detector de movimiento cuando vea movimiento.
    func motionDetected() {
        runOnMain {
            self.lastMotion = Date()
            self.update()
        }
    }

    private func targetLevel(now: Date) -> CGFloat {
        if now.timeIntervalSince(lastTouch) < BrightnessConfig.touchSeconds {
            return BrightnessConfig.maxLevel
        }
        if now.timeIntervalSince(lastMotion) < BrightnessConfig.idleSeconds {
            return BrightnessConfig.motionLevel
        }
        return BrightnessConfig.minLevel
    }

    private func update() {
        guard timer != nil else { return }
        let level = targetLevel(now: Date())
        guard level != currentLevel else { return }
        currentLevel = level
        changeLock.lock()
        changedAt = Date()
        changeLock.unlock()
        // La pantalla ilumina la habitación: la cámara debe ignorar este cambio.
        MotionGuard.shared.suppress(for: 2.0)
        UIScreen.main.brightness = level
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
