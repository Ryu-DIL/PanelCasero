import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var favorites: FavoritesStore
    @EnvironmentObject var camera: CameraManager
    @EnvironmentObject var link: DeviceLink
    @EnvironmentObject var alarm: AlarmController
    @EnvironmentObject var weather: WeatherService
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

                if alarm.showingPIN {
                    pinOverlay
                }
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(favorites)
                .environmentObject(camera)
                .environmentObject(link)
                .environmentObject(alarm)
                .environmentObject(weather)
                .preferredColorScheme(settings.colorScheme)
        }
    }

    /// Teclado para desarmar la alarma. Se cierra solo a los 30 s.
    private var pinOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { alarm.showingPIN = false }
            PINPadView(title: settings.t("pin_enter"),
                       length: settings.alarmPINLength,
                       onComplete: { pin in
                           if alarm.checkPIN(pin) {
                               alarm.disarm()
                               return true
                           }
                           return false
                       },
                       onCancel: { alarm.showingPIN = false })
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
        }
        .task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                alarm.showingPIN = false
            }
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
