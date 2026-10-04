import SwiftUI

/// Previsión de hoy: icono, temperatura máxima/mínima y probabilidad de lluvia.
struct WeatherPanel: View {
    @EnvironmentObject var weather: WeatherService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: weather.forecast?.symbolName ?? "cloud.fill")
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 3) {
                Text(temperatureText)
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text(rainText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
    }

    private var temperatureText: String {
        guard let forecast = weather.forecast else { return "--° / --°" }
        return "\(Int(forecast.tempMax.rounded()))° / \(Int(forecast.tempMin.rounded()))°"
    }

    private var rainText: String {
        guard let chance = weather.forecast?.rainChance else { return "--%" }
        return "\(chance) %"
    }
}
