import SwiftUI

/// La cámara es una ventana, no una tarjeta: el marco se ilumina cuando algo se mueve.
/// El candado de la alarma es una pastilla discreta con su estado escrito.
struct CameraPanel: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var camera: CameraManager
    @EnvironmentObject var alarm: AlarmController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.surface
            content
            controls
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(camera.motionActive ? Theme.lamp : Theme.hairline,
                              lineWidth: camera.motionActive ? 2 : 1)
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: camera.motionActive)
    }

    @ViewBuilder
    private var content: some View {
        switch camera.state {
        case .running:
            CameraPreview(session: camera.session, running: true,
                          onOrientation: { camera.setVideoOrientation($0) })
        case .denied:
            notice(icon: "video.slash.fill", text: settings.t("camera_denied"))
        case .unavailable:
            notice(icon: "video.slash.fill", text: settings.t("camera_unavailable"))
        case .idle:
            ProgressView()
        }
    }

    private var controls: some View {
        VStack {
            HStack(alignment: .top) {
                if camera.reducedMode {
                    Image(systemName: "thermometer.sun.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.lamp)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                Spacer()
                lockPill
            }
            Spacer()
            if let text = alarm.message {
                Text(text)
                    .font(.label(12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
            }
        }
        .padding(10)
    }

    /// Candado: abierto = desarmada; cerrado = armada. Nunca muestra cuentas atrás.
    private var lockPill: some View {
        let armed = alarm.state != .disarmed
        return Button(action: { alarm.lockTapped() }) {
            HStack(spacing: 6) {
                Image(systemName: armed ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(armed ? settings.t("alarm_on") : settings.t("alarm_off"))
                    .font(.label(12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Capsule().fill(armed ? Theme.signal : Color.black.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(armed ? 0 : 0.18), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(armed ? settings.t("alarm_on") : settings.t("alarm_off"))
    }

    private func notice(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
            Text(text)
                .font(.label(12))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(Theme.textMuted)
        .padding(16)
    }
}
