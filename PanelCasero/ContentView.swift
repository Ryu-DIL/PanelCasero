import SwiftUI

/// Reparto de la pantalla. Cada bloque mantiene su identidad al girar el móvil: solo cambia
/// su rectángulo. (Si se cambiase de una estructura de vistas a otra, la cámara se destruiría
/// y volvería a crearse en cada giro, que era lo que hacía la versión anterior.)
struct PanelLayout {
    let camera: CGRect
    let clock: CGRect
    let weather: CGRect
    let lights: CGRect
    let compactClock: Bool

    init(size: CGSize) {
        let margin: CGFloat = 12
        let gap: CGFloat = 10
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let usableW = width - margin * 2
        let usableH = height - margin * 2

        if width > height {
            // Horizontal: cámara a la izquierda; hora, tiempo y luces a la derecha.
            let cameraW = ((usableW - 12) * 0.56).rounded()
            let rightX = margin + cameraW + 12
            let rightW = usableW - cameraW - 12
            let clockH = min(108, usableH * 0.32)
            let weatherH: CGFloat = 46
            let lightsH = max(usableH - clockH - weatherH - gap * 2, 80)
            camera = CGRect(x: margin, y: margin, width: cameraW, height: usableH)
            clock = CGRect(x: rightX, y: margin, width: rightW, height: clockH)
            weather = CGRect(x: rightX, y: margin + clockH + gap, width: rightW, height: weatherH)
            lights = CGRect(x: rightX, y: margin + clockH + weatherH + gap * 2, width: rightW, height: lightsH)
            compactClock = false
        } else {
            // Vertical: hora, cámara, tiempo y luces apilados.
            let clockH: CGFloat = 84
            let weatherH: CGFloat = 46
            let lightsH: CGFloat = 116
            let cameraH = max(usableH - clockH - weatherH - lightsH - gap * 3, 120)
            let cameraY = margin + clockH + gap
            let weatherY = cameraY + cameraH + gap
            clock = CGRect(x: margin, y: margin, width: usableW, height: clockH)
            camera = CGRect(x: margin, y: cameraY, width: usableW, height: cameraH)
            weather = CGRect(x: margin, y: weatherY, width: usableW, height: weatherH)
            lights = CGRect(x: margin, y: weatherY + weatherH + gap, width: usableW, height: lightsH)
            compactClock = true
        }
    }
}

struct ContentView: View {
    let env: AppEnvironment
    // Solo lo que esta pantalla necesita de verdad: el resto lo observa cada bloque por su cuenta.
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var alarm: AlarmController
    @ObservedObject private var dim = DimState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let layout = PanelLayout(size: geo.size)
            ZStack(alignment: .topLeading) {
                Theme.background.ignoresSafeArea()

                CameraPanel().placed(layout.camera)
                ClockPanel(compact: layout.compactClock, onSettings: { showSettings = true })
                    .placed(layout.clock)
                WeatherPanel().placed(layout.weather)
                LightsPanel().placed(layout.lights)

                if alarm.showingPIN {
                    pinOverlay
                }

                // En reposo la pantalla se oscurece por software, por debajo incluso del mínimo de iOS.
                Color.black
                    .opacity(dim.overlay)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: dim.overlay)
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .injecting(env)
                .preferredColorScheme(settings.colorScheme)
        }
    }

    /// Teclado para desarmar la alarma. Se cierra solo a los 30 s.
    private var pinOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
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
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                        .fill(Theme.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !Task.isCancelled {
                alarm.showingPIN = false
            }
        }
    }
}
