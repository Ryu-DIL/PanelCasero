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
    private(set) var lastChange: Date = .distantPast

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
        lastChange = Date()
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

extension View {
    /// Avisa al controlador de brillo cada vez que se toca la pantalla.
    func trackTouches() -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in BrightnessController.shared.touched() }
        )
    }
}
