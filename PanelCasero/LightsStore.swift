import SwiftUI

/// Guarda el estado de las luces, lo refresca y envía las órdenes al servidor.
///
/// Los cambios se ven al instante en pantalla (estado "optimista") y las órdenes
/// se agrupan: solo hay una petición en vuelo por luz y, si llegan varias
/// mientras tanto (por ejemplo al arrastrar un deslizador), se envía la última.
@MainActor
final class LightsStore: ObservableObject {
    enum Status {
        case notConfigured, connected, unauthorized, unreachable
    }

    @Published private(set) var lights: [String: LightState] = [:]
    @Published private(set) var status: Status = .notConfigured

    private let settings: AppSettings
    private var pollTask: Task<Void, Never>?
    private var inFlight = Set<String>()
    private var pending = [String: LightCommand]()
    private var lastCommand = [String: Date]()

    init(settings: AppSettings) {
        self.settings = settings
    }

    private func makeClient() -> LightsClient? {
        LightsClient.make(address: settings.serverURL, token: settings.serverToken)
    }

    // MARK: - Consulta periódica

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard let client = makeClient() else {
            status = .notConfigured
            return
        }
        do {
            let list = try await client.fetchAll()
            status = .connected
            for light in list where !isBusy(light.id) {
                if let old = lights[light.id], visiblyChanged(old, light) {
                    // Alguien (Alexa, la app de Tuya...) ha cambiado la luz.
                    MotionGuard.shared.suppress(for: 5)
                }
                lights[light.id] = light
            }
        } catch LightsError.unauthorized {
            status = .unauthorized
        } catch {
            status = .unreachable
        }
    }

    /// Para el botón "Probar conexión" de Ajustes.
    func testConnection() async -> Status {
        guard let client = makeClient() else { return .notConfigured }
        do {
            _ = try await client.fetchAll()
            return .connected
        } catch LightsError.unauthorized {
            return .unauthorized
        } catch {
            return .unreachable
        }
    }

    private func visiblyChanged(_ old: LightState, _ new: LightState) -> Bool {
        old.on != new.on
            || old.mode != new.mode
            || abs(old.brightness - new.brightness) > 2
            || abs(old.hue - new.hue) > 2
            || abs(old.saturation - new.saturation) > 2
            || abs(old.temperature - new.temperature) > 2
    }

    private func isBusy(_ id: String) -> Bool {
        if inFlight.contains(id) || pending[id] != nil { return true }
        if let last = lastCommand[id], Date().timeIntervalSince(last) < 3 { return true }
        return false
    }

    // MARK: - Órdenes

    func send(_ id: String, _ command: LightCommand) {
        // La luz de la habitación va a cambiar: la cámara no debe tomarlo por movimiento.
        MotionGuard.shared.suppress(for: 5)
        applyOptimistic(id, command)
        lastCommand[id] = Date()
        pending[id] = command
        if !inFlight.contains(id) {
            drain(id)
        }
    }

    private func drain(_ id: String) {
        guard let command = pending[id], let client = makeClient() else {
            pending[id] = nil
            return
        }
        pending[id] = nil
        inFlight.insert(id)
        Task {
            do {
                let state = try await client.send(id, command)
                if pending[id] == nil {
                    lights[id] = state
                }
                status = .connected
            } catch LightsError.unauthorized {
                status = .unauthorized
            } catch LightsError.server(let code, _) {
                if code == 502 { lights[id]?.online = false }
            } catch {
                lights[id]?.online = false
                status = .unreachable
            }
            inFlight.remove(id)
            lastCommand[id] = Date()
            if pending[id] != nil {
                drain(id)
            }
        }
    }

    private func applyOptimistic(_ id: String, _ command: LightCommand) {
        guard var light = lights[id] else { return }
        switch command {
        case .power(let on):
            light.on = on
        case .color(let hue, let saturation, let brightness):
            light.on = true
            light.mode = "colour"
            light.hue = hue
            light.saturation = saturation
            light.brightness = brightness
        case .white(let brightness, let temperature):
            light.on = true
            light.mode = "white"
            light.brightness = brightness
            light.temperature = temperature
        }
        lights[id] = light
    }
}
