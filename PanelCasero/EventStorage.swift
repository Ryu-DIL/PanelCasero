import Foundation

/// Un evento (alerta o prueba) pendiente de enviar al servidor.
struct PendingEvent: Codable {
    let id: String
    let kind: String
    let created: Double            // segundos desde 1970
    var createdOnServer = false
    var photoDone = false
    var clipExpected = true        // se espera un clip de vídeo
    var clipReady = false          // el clip ya está grabado y completo
    var clipDone = false           // el clip ya se subió
    var reason: String? = nil      // "motion" o "pin" (por qué saltó la alerta)
    var held: Bool? = nil          // true = guardado pero sin enviar todavía (espera al PIN)
}

/// Cola de eventos en disco: sobrevive a reinicios y a falta de conexión.
/// Cada evento vive en su carpeta: event.json, photo.jpg y clip.mp4.
enum EventStorage {
    private static let lock = NSLock()

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("PanelCasero/Events", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func folder(_ id: String) -> URL {
        root.appendingPathComponent(id, isDirectory: true)
    }

    static func photoURL(_ id: String) -> URL { folder(id).appendingPathComponent("photo.jpg") }
    static func clipURL(_ id: String) -> URL { folder(id).appendingPathComponent("clip.mp4") }
    private static func jsonURL(_ id: String) -> URL { folder(id).appendingPathComponent("event.json") }

    /// Guarda un evento nuevo con su foto.
    static func begin(id: String, kind: String, created: Date, jpeg: Data,
                      held: Bool = false, reason: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.createDirectory(at: folder(id), withIntermediateDirectories: true)
        try? jpeg.write(to: photoURL(id), options: .atomic)
        var event = PendingEvent(id: id, kind: kind, created: created.timeIntervalSince1970)
        event.held = held ? true : nil
        event.reason = reason
        saveEvent(event)
    }

    /// Eventos pendientes, del más antiguo al más reciente.
    static func list() -> [PendingEvent] {
        lock.lock()
        defer { lock.unlock() }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.compactMap { loadEvent($0) }.sorted { $0.created < $1.created }
    }

    static func exists(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return loadEvent(id) != nil
    }

    static func update(_ id: String, _ change: (inout PendingEvent) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard var event = loadEvent(id) else { return }
        change(&event)
        saveEvent(event)
    }

    /// Si el servidor lleva mucho tiempo sin responder, se descartan los eventos más antiguos.
    static func trim(maxEvents: Int) {
        let events = list().filter { $0.held != true }
        guard events.count > maxEvents else { return }
        for event in events.prefix(events.count - maxEvents) {
            remove(event.id)
        }
    }

    static func remove(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: folder(id))
    }

    // MARK: - Internos (se llaman con el bloqueo ya cogido)

    private static func loadEvent(_ id: String) -> PendingEvent? {
        guard let data = try? Data(contentsOf: jsonURL(id)) else { return nil }
        return try? JSONDecoder().decode(PendingEvent.self, from: data)
    }

    private static func saveEvent(_ event: PendingEvent) {
        if let data = try? JSONEncoder().encode(event) {
            try? data.write(to: jsonURL(event.id), options: .atomic)
        }
    }
}
