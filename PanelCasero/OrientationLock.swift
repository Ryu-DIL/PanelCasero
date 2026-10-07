import SwiftUI
import UIKit

enum OrientationMode: String, CaseIterable, Identifiable {
    case landscape, portrait, auto

    var id: String { rawValue }
}

/// Orientación de la pantalla. Un panel de pared está siempre colgado igual, así que lo normal
/// es fijarla: girar el móvil con la cámara en marcha es lo más pesado que puede hacer la app.
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .landscape

    static func apply(_ mode: OrientationMode) {
        switch mode {
        case .landscape: mask = .landscape
        case .portrait: mask = .portrait
        case .auto: mask = [.portrait, .landscapeLeft, .landscapeRight]
        }
        rotateIfNeeded(mode)
    }

    private static func rotateIfNeeded(_ mode: OrientationMode) {
        let current = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation
        switch mode {
        case .landscape:
            if !(current?.isLandscape ?? false) {
                // El nombre de la orientación del dispositivo y de la interfaz van cruzados en horizontal.
                let device = UIDevice.current.orientation
                force(device == .landscapeRight ? .landscapeLeft : .landscapeRight)
            }
        case .portrait:
            if current != .portrait {
                force(.portrait)
            }
        case .auto:
            break
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private static func force(_ orientation: UIInterfaceOrientation) {
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
