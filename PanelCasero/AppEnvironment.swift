import SwiftUI

/// Referencias a todos los objetos de la app. No es observable a propósito: sirve para
/// pasárselos a las ventanas emergentes sin que la pantalla principal se redibuje cada vez
/// que cambia algo en cualquiera de ellos.
struct AppEnvironment {
    let settings: AppSettings
    let store: LightsStore
    let link: DeviceLink
    let alarm: AlarmController
    let weather: WeatherService
    let favorites: FavoritesStore
    let camera: CameraManager
}

extension View {
    func injecting(_ env: AppEnvironment) -> some View {
        self.environmentObject(env.settings)
            .environmentObject(env.store)
            .environmentObject(env.link)
            .environmentObject(env.alarm)
            .environmentObject(env.weather)
            .environmentObject(env.favorites)
            .environmentObject(env.camera)
    }

    /// Coloca una vista en un rectángulo concreto de la pantalla. El giro no se anima:
    /// es más barato y evita rebotes de la imagen de la cámara.
    func placed(_ rect: CGRect) -> some View {
        self.frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .transaction { $0.animation = nil }
    }
}
