import SwiftUI

/// Vista de la cámara con el candado de la alarma. Un punto rojo indica movimiento.
struct CameraPanel: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var camera: CameraManager
    @EnvironmentObject var alarm: AlarmController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)

            switch camera.state {
            case .running:
                CameraPreview(session: camera.session, running: true,
                              onOrientation: { camera.setVideoOrientation($0) })
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            case .denied:
                message(settings.t("camera_denied"))
            case .unavailable:
                message(settings.t("camera_unavailable"))
            case .idle:
                ProgressView()
            }

            VStack {
                HStack(alignment: .top) {
                    Circle()
                        .fill(camera.motionActive ? Color.red : Color.clear)
                        .frame(width: 10, height: 10)
                        .padding(.top, 14)
                    if camera.reducedMode {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .padding(.top, 10)
                    }
                    Spacer()
                    lockButton
                }
                Spacer()
                if let text = alarm.message {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Candado: abierto = desarmada; cerrado = armada (sin mostrar cuentas atrás).
    private var lockButton: some View {
        Button(action: { alarm.lockTapped() }) {
            Image(systemName: alarm.state == .disarmed ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(alarm.state == .disarmed ? Color.black.opacity(0.45) : Color.red.opacity(0.85))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 26))
            Text(text)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(Color.white.opacity(0.7))
        .padding(12)
    }
}
