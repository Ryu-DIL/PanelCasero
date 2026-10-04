import SwiftUI

/// Previsión del día.
struct DailyForecast: Codable, Equatable {
    var code: Int           // código WMO del tiempo
    var tempMax: Double
    var tempMin: Double
    var rainChance: Int?    // probabilidad de lluvia (%), si hay dato
    var day: String         // "2026-10-05"

    /// Icono del tiempo (códigos WMO que usa Open-Meteo).
    var symbolName: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: return "cloud.rain.fill"
        case 65, 67, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

private struct Place: Codable {
    var query: String
    var name: String
    var latitude: Double
    var longitude: Double
}

private struct ForecastResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_probability_max: [Int?]?
    }

    let daily: Daily

    func today() -> DailyForecast? {
        guard let day = daily.time.first,
              let code = daily.weather_code.first ?? nil,
              let high = daily.temperature_2m_max.first ?? nil,
              let low = daily.temperature_2m_min.first ?? nil else { return nil }
        let rain = daily.precipitation_probability_max?.first ?? nil
        return DailyForecast(code: code, tempMax: high, tempMin: low, rainChance: rain, day: day)
    }
}

private struct GeocodingResponse: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    let results: [Result]?
}

/// Previsión del tiempo de hoy con Open-Meteo (gratuita y sin clave).
/// Se actualiza cada 30 minutos y guarda la última por si no hay internet.
@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var forecast: DailyForecast?
    @Published private(set) var placeName = ""

    private let settings: AppSettings
    private var loop: Task<Void, Never>?
    private static let session = URLSession(configuration: .ephemeral)
    private static let forecastKey = "weatherForecast"
    private static let placeKey = "weatherPlace"

    init(settings: AppSettings) {
        self.settings = settings
        if let data = UserDefaults.standard.data(forKey: Self.forecastKey) {
            forecast = try? JSONDecoder().decode(DailyForecast.self, from: data)
        }
        placeName = loadPlace()?.name ?? ""
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func refresh() async {
        let city = settings.weatherCity.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty, let place = await place(for: city) else { return }
        placeName = place.name

        let address = "https://api.open-meteo.com/v1/forecast?latitude=\(place.latitude)"
            + "&longitude=\(place.longitude)"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=1"
        guard let url = URL(string: address),
              let result = try? await Self.session.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ForecastResponse.self, from: result.0),
              let today = decoded.today() else { return }
        forecast = today
        if let data = try? JSONEncoder().encode(today) {
            UserDefaults.standard.set(data, forKey: Self.forecastKey)
        }
    }

    // MARK: - Búsqueda de la ciudad

    private func loadPlace() -> Place? {
        guard let data = UserDefaults.standard.data(forKey: Self.placeKey) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    private func place(for city: String) async -> Place? {
        if let cached = loadPlace(), cached.query.lowercased() == city.lowercased() {
            return cached
        }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "format", value: "json")
        ]
        if let url = components?.url,
           let result = try? await Self.session.data(from: url),
           let decoded = try? JSONDecoder().decode(GeocodingResponse.self, from: result.0),
           let first = decoded.results?.first {
            let place = Place(query: city, name: first.name, latitude: first.latitude, longitude: first.longitude)
            if let data = try? JSONEncoder().encode(place) {
                UserDefaults.standard.set(data, forKey: Self.placeKey)
            }
            return place
        }
        // Sin internet para buscar la ciudad: se usa la última conocida; Mislata siempre está disponible.
        if let cached = loadPlace() { return cached }
        if city.lowercased() == "mislata" {
            return Place(query: city, name: "Mislata", latitude: 39.4747, longitude: -0.4177)
        }
        return nil
    }
}
