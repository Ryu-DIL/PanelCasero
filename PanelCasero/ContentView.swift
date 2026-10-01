import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if geo.size.width > geo.size.height {
                    landscapeLayout(width: geo.size.width)
                } else {
                    portraitLayout
                }
            }
        }
        .statusBarHidden(true)
        .trackTouches()
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
                .trackTouches()
        }
    }

    /// Horizontal: cámara a la izquierda; reloj, tiempo y luces a la derecha.
    private func landscapeLayout(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            CameraPanel()
                .frame(width: width * 0.55)
            VStack(spacing: 10) {
                ClockPanel(onSettings: { showSettings = true })
                WeatherPanel()
                LightsPanel()
            }
        }
        .padding(10)
    }

    /// Vertical: todo apilado.
    private var portraitLayout: some View {
        VStack(spacing: 10) {
            ClockPanel(onSettings: { showSettings = true })
            CameraPanel()
            WeatherPanel()
            LightsPanel()
        }
        .padding(10)
    }
}
