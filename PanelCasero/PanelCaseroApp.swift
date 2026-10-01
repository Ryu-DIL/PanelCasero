import SwiftUI

@main
struct PanelCaseroApp: App {
    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
                .onAppear {
                    // La pantalla nunca se apaga sola.
                    UIApplication.shared.isIdleTimerDisabled = true
                    BrightnessController.shared.start()
                    TouchWatcher.install()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                BrightnessController.shared.start()
            } else {
                // Al salir de la app, el iPhone recupera su brillo normal.
                BrightnessController.shared.stop()
            }
        }
    }
}
