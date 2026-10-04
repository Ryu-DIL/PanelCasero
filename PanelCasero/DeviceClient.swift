import Foundation

/// Habla con el servidor como "dispositivo" (la cámara): latidos y eventos.
struct DeviceClient {
    let baseURL: String
    let token: String

    private static let session = URLSession(configuration: .ephemeral)

    static func make(address: String, token: String) -> DeviceClient? {
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
        return DeviceClient(baseURL: text, token: key)
    }

    func heartbeat(battery: Double?, charging: Bool?, alarm: String?) async throws {
        var body: [String: Any] = [:]
        if let battery = battery { body["battery"] = battery }
        if let charging = charging { body["charging"] = charging }
        if let alarm = alarm { body["alarm"] = alarm }
        let data = try JSONSerialization.data(withJSONObject: body)
        try await send(path: "/api/device/heartbeat", method: "POST", json: data, file: nil, contentType: nil)
    }

    func putEvent(id: String, kind: String, created: Double, reason: String?) async throws {
        var body: [String: Any] = ["kind": kind, "created": created]
        if let reason = reason { body["reason"] = reason }
        let data = try JSONSerialization.data(withJSONObject: body)
        try await send(path: "/api/device/events/\(id)", method: "PUT", json: data, file: nil, contentType: nil)
    }

    func upload(path: String, file: URL, contentType: String) async throws {
        try await send(path: path, method: "PUT", json: nil, file: file, contentType: contentType)
    }

    // MARK: - Interno

    private func send(path: String, method: String, json: Data?, file: URL?, contentType: String?) async throws {
        guard let url = URL(string: baseURL + path) else { throw LightsError.unreachable }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = file == nil ? 8 : 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let result: (Data, URLResponse)
        do {
            if let file = file {
                request.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
                result = try await Self.session.upload(for: request, fromFile: file)
            } else {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = json
                result = try await Self.session.data(for: request)
            }
        } catch {
            throw LightsError.unreachable
        }
        guard let http = result.1 as? HTTPURLResponse else { throw LightsError.unreachable }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw LightsError.unauthorized
        default: throw LightsError.server(http.statusCode, "")
        }
    }
}
