import SwiftUI

@main
struct PanelCaseroApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var store: LightsStore
    @StateObject private var favorites = FavoritesStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: LightsStore(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(favorites)
                .preferredColorScheme(settings.colorScheme)
                .onAppear {
                    // La pantalla nunca se apaga sola.
                    UIApplication.shared.isIdleTimerDisabled = true
                    BrightnessController.shared.start()
                    TouchWatcher.install()
                    store.startPolling()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                BrightnessController.shared.start()
                store.startPolling()
            } else {
                // Al salir de la app, el iPhone recupera su brillo normal.
                BrightnessController.shared.stop()
                store.stopPolling()
            }
        }
    }
}
