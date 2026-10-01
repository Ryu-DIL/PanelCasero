import SwiftUI

/// De momento solo marca el sitio de la cámara (se rellena en la fase 3).
struct CameraPanel: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.85))
            VStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 30))
                Text(settings.t("camera"))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
