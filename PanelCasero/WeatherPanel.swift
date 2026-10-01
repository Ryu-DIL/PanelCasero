import SwiftUI

/// De momento muestra datos de relleno (la previsión real llega más adelante).
struct WeatherPanel: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 3) {
                Text("--° / --°")
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("--%")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
    }
}
