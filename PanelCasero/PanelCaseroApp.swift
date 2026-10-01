import SwiftUI

@main
struct PanelCaseroApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
                .onAppear {
                    // La pantalla nunca se apaga sola.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
