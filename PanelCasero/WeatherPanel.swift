import SwiftUI

/// Previsión de hoy en una sola línea: icono, máxima, mínima y probabilidad de lluvia.
struct WeatherPanel: View {
    @EnvironmentObject var weather: WeatherService

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.forecast?.symbolName ?? "cloud.fill")
                .font(.system(size: 24))
                .symbolRenderingMode(.multicolor)
                .frame(width: 32)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(high)
                    .font(.numeral(26, weight: .regular))
                    .foregroundColor(Theme.text)
                Text(low)
                    .font(.numeral(20, weight: .regular))
                    .foregroundColor(Theme.textMuted)
            }
            .monospacedDigit()
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.36, green: 0.62, blue: 0.95))
                Text(rain)
                    .font(.label(14))
                    .monospacedDigit()
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
    }

    private var high: String {
        guard let forecast = weather.forecast else { return "--°" }
        return "\(Int(forecast.tempMax.rounded()))°"
    }

    private var low: String {
        guard let forecast = weather.forecast else { return "--°" }
        return "\(Int(forecast.tempMin.rounded()))°"
    }

    private var rain: String {
        guard let chance = weather.forecast?.rainChance else { return "--%" }
        return "\(chance)%"
    }
}
