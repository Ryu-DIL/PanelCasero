import SwiftUI

/// Vista de la cámara. Muestra un punto rojo cuando detecta movimiento.
struct CameraPanel: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var camera: CameraManager

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)

            switch camera.state {
            case .running:
                CameraPreview(session: camera.session, running: true)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            case .denied:
                message(settings.t("camera_denied"))
            case .unavailable:
                message(settings.t("camera_unavailable"))
            case .idle:
                ProgressView()
            }

            VStack {
                HStack {
                    Circle()
                        .fill(camera.motionActive ? Color.red : Color.clear)
                        .frame(width: 10, height: 10)
                    Spacer()
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
