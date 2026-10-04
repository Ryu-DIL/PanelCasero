import SwiftUI
import UIKit

/// Enlace con el servidor: latido cada 30 s y envío de eventos pendientes.
/// Si no hay conexión, los eventos se quedan en disco y se envían al volver.
@MainActor
final class DeviceLink: ObservableObject {
    @Published private(set) var pendingCount = 0
    /// nil = aún sin datos o sin configurar.
    @Published private(set) var serverReachable: Bool? = nil

    /// Estado de la alarma que se manda en cada latido (lo pone la app al arrancar).
    var alarmState: () -> String? = { nil }
    /// Se llama cuando la foto de un evento ya está en el servidor (el servidor avisa al móvil).
    var onPhotoUploaded: ((String) -> Void)?

    private let settings: AppSettings
    private var loop: Task<Void, Never>?
    private var processing = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    private func makeClient() -> DeviceClient? {
        DeviceClient.make(address: settings.serverURL, token: settings.serverToken)
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Intenta enviar ya lo pendiente (nuevo evento, cambio de ajustes...).
    func kick() {
        Task { await processQueue() }
    }

    /// Manda un latido ya (por ejemplo, al armar o desarmar la alarma).
    func sendHeartbeatSoon() {
        Task { await heartbeat() }
    }

    private func tick() async {
        await heartbeat()
        await processQueue()
    }

    // MARK: - Latido

    private func heartbeat() async {
        guard let client = makeClient() else {
            serverReachable = nil
            return
        }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level: Double? = device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil
        let charging = device.batteryState == .charging || device.batteryState == .full
        do {
            try await client.heartbeat(battery: level, charging: charging, alarm: alarmState(),
                                       thermal: Self.thermalName())
            serverReachable = true
        } catch {
            serverReachable = false
        }
    }

    /// Estado térmico del iPhone: nominal, fair, serious o critical.
    private static func thermalName() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "nominal"
        }
    }

    // MARK: - Cola de eventos

    func processQueue() async {
        if processing { return }
        processing = true
        defer {
            processing = false
            pendingCount = EventStorage.list().count
        }
        guard let client = makeClient() else { return }

        for event in EventStorage.list() where event.held != true {
            do {
                try await process(event, client)
            } catch LightsError.server(let code, _) {
                if code == 400 || code == 413 {
                    EventStorage.remove(event.id)          // el servidor lo rechaza: no se reintenta
                } else if code == 404 {
                    EventStorage.update(event.id) { $0.createdOnServer = false }
                    return
                } else {
                    return
                }
            } catch {
                return                                      // sin conexión o clave mala: se reintenta luego
            }
        }
    }

    private func process(_ initial: PendingEvent, _ client: DeviceClient) async throws {
        var event = initial
        let fileManager = FileManager.default

        if !event.photoDone && !fileManager.fileExists(atPath: EventStorage.photoURL(event.id).path) {
            EventStorage.remove(event.id)                   // sin foto no hay nada que enviar
            return
        }

        if !event.createdOnServer {
            try await client.putEvent(id: event.id, kind: event.kind, created: event.created,
                                      reason: event.reason)
            EventStorage.update(event.id) { $0.createdOnServer = true }
            event.createdOnServer = true
        }

        if !event.photoDone {
            try await client.upload(path: "/api/device/events/\(event.id)/photo",
                                    file: EventStorage.photoURL(event.id), contentType: "image/jpeg")
            EventStorage.update(event.id) { $0.photoDone = true }
            event.photoDone = true
            onPhotoUploaded?(event.id)
        }

        if event.clipExpected && !event.clipDone {
            if event.clipReady && fileManager.fileExists(atPath: EventStorage.clipURL(event.id).path) {
                try await client.upload(path: "/api/device/events/\(event.id)/clip",
                                        file: EventStorage.clipURL(event.id), contentType: "video/mp4")
                EventStorage.update(event.id) { $0.clipDone = true }
                event.clipDone = true
            } else if Date().timeIntervalSince1970 - event.created > 90 {
                // El clip no llegó a terminarse (la app se cerró, por ejemplo): se renuncia a él.
                EventStorage.update(event.id) { $0.clipExpected = false }
                event.clipExpected = false
            }
        }

        if event.photoDone && (!event.clipExpected || event.clipDone) {
            EventStorage.remove(event.id)
        }
    }
}
