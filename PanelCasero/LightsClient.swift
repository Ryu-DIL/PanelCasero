import Foundation

/// Habla con el servidor de PanelCasero (API REST en la red local).
struct LightsClient {
    let baseURL: String
    let token: String

    private static let session = URLSession(configuration: .ephemeral)

    /// Devuelve nil si falta la dirección o la clave.
    static func make(address: String, token: String) -> LightsClient? {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !key.isEmpty else { return nil }
        let lower = text.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }
        return LightsClient(baseURL: text, token: key)
    }

    func fetchAll() async throws -> [LightState] {
        let data = try await call(path: "/api/lights", method: "GET", body: nil)
        return try decode([LightState].self, from: data)
    }

    func send(_ id: String, _ command: LightCommand) async throws -> LightState {
        let path: String
        let body: [String: Any]
        switch command {
        case .power(let on):
            path = "power"
            body = ["on": on]
        case .color(let hue, let saturation, let brightness):
            path = "color"
            body = ["hue": hue, "saturation": saturation, "brightness": brightness]
        case .white(let brightness, let temperature):
            path = "white"
            body = ["brightness": brightness, "temperature": temperature]
        }
        let data = try await call(path: "/api/lights/\(id)/\(path)", method: "POST", body: body)
        return try decode(LightState.self, from: data)
    }

    // MARK: - Internos

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw LightsError.server(0, "Respuesta no válida")
        }
    }

    private func call(path: String, method: String, body: [String: Any]?) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw LightsError.unreachable
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 6
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let result: (Data, URLResponse)
        do {
            result = try await Self.session.data(for: request)
        } catch {
            throw LightsError.unreachable
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw LightsError.unreachable
        }
        switch http.statusCode {
        case 200..<300:
            return result.0
        case 401:
            throw LightsError.unauthorized
        default:
            throw LightsError.server(http.statusCode, Self.detail(from: result.0))
        }
    }

    private static func detail(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["detail"] as? String {
            return text
        }
        return ""
    }
}
