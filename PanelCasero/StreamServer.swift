import Foundation
import Network

/// Pequeño servidor web del iPhone para el directo de la cámara.
///   GET /stream        -> vídeo MJPEG continuo
///   GET /snapshot.jpg  -> la última imagen
/// Exige la cabecera "Authorization: Bearer <clave>". Solo lo usa el servidor de casa.
final class StreamServer {
    static let shared = StreamServer()
    static let port: UInt16 = 8081

    private final class Client {
        let connection: NWConnection
        var busy = false
        init(_ connection: NWConnection) { self.connection = connection }
    }

    private let queue = DispatchQueue(label: "panelcasero.stream")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var latest: Data?

    /// Atiende las órdenes de la alarma que llegan desde el servidor ("arm", "disarm", "state").
    /// Debe responder con el estado resultante. Se asigna una vez, antes de `start()`.
    var alarmHandler: ((String, @escaping (String?) -> Void) -> Void)?

    private let stateLock = NSLock()
    private var viewerCount = 0
    private var token = ""

    private init() {}

    /// true si alguien está viendo el directo (la cámara codifica más imágenes por segundo).
    var hasClients: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return viewerCount > 0
    }

    func setToken(_ value: String) {
        stateLock.lock()
        token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        stateLock.unlock()
    }

    private func currentToken() -> String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return token
    }

    // MARK: - Arranque y parada

    func start() {
        queue.async {
            guard self.listener == nil,
                  let port = NWEndpoint.Port(rawValue: Self.port),
                  let listener = try? NWListener(using: .tcp, on: port) else { return }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    // Si el sistema lo cierra (por ejemplo al volver de segundo plano), se reabre.
                    self?.stop()
                    self?.queue.asyncAfter(deadline: .now() + 2) { self?.start() }
                }
            }
            listener.start(queue: self.queue)
            self.listener = listener
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            for client in self.clients.values {
                client.connection.cancel()
            }
            self.clients.removeAll()
            self.updateCount()
        }
    }

    // MARK: - Imágenes de la cámara

    /// La cámara entrega aquí cada JPEG.
    func publish(_ jpeg: Data) {
        queue.async {
            self.latest = jpeg
            guard !self.clients.isEmpty else { return }
            var part = Data("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n".utf8)
            part.append(jpeg)
            part.append(Data("\r\n".utf8))
            for client in self.clients.values where !client.busy {
                client.busy = true
                client.connection.send(content: part, completion: .contentProcessed { [weak self] error in
                    if error != nil {
                        self?.remove(client)
                    } else {
                        client.busy = false
                    }
                })
            }
        }
    }

    // MARK: - Conexiones

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        // Una conexión que no termina de pedir nada se cierra, para no acumular conexiones muertas.
        let timeout = DispatchWorkItem { [weak connection] in connection?.cancel() }
        queue.asyncAfter(deadline: .now() + 10, execute: timeout)
        receiveRequest(connection, buffer: Data(), timeout: timeout)
    }

    private func receiveRequest(_ connection: NWConnection, buffer: Data, timeout: DispatchWorkItem) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var received = buffer
            if let data = data {
                received.append(data)
            }
            if let end = received.range(of: Data("\r\n\r\n".utf8)) {
                timeout.cancel()
                let head = String(decoding: received[..<end.lowerBound], as: UTF8.self)
                self.respond(to: connection, head: head)
            } else if error != nil || isComplete || received.count > 8192 {
                timeout.cancel()
                connection.cancel()
            } else {
                self.receiveRequest(connection, buffer: received, timeout: timeout)
            }
        }
    }

    private func respond(to connection: NWConnection, head: String) {
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "POST" else {
            reply(connection, status: "405 Method Not Allowed", body: Data(), type: "text/plain")
            return
        }
        let method = String(parts[0])
        let path = String(parts[1]).components(separatedBy: "?")[0]

        var authorization = ""
        for line in lines.dropFirst() where line.lowercased().hasPrefix("authorization:") {
            authorization = String(line.dropFirst("authorization:".count)).trimmingCharacters(in: .whitespaces)
        }
        let key = currentToken()
        guard !key.isEmpty, authorization == "Bearer \(key)" else {
            reply(connection, status: "401 Unauthorized", body: Data(), type: "text/plain")
            return
        }

        switch path {
        case "/alarm", "/alarm/arm", "/alarm/disarm":
            let action = path == "/alarm" ? "state" : String(path.dropFirst("/alarm/".count))
            guard action == "state" || method == "POST" else {
                reply(connection, status: "405 Method Not Allowed", body: Data(), type: "text/plain")
                return
            }
            guard let handler = alarmHandler else {
                reply(connection, status: "503 Service Unavailable", body: Data(), type: "text/plain")
                return
            }
            handler(action) { [weak self] state in
                self?.queue.async {
                    guard let state = state else {
                        self?.reply(connection, status: "503 Service Unavailable", body: Data(), type: "text/plain")
                        return
                    }
                    self?.reply(connection, status: "200 OK", body: Data("{\"state\":\"\(state)\"}".utf8),
                                type: "application/json")
                }
            }
        case "/stream":
            startStream(connection)
        case "/snapshot.jpg":
            if let latest = latest {
                reply(connection, status: "200 OK", body: latest, type: "image/jpeg")
            } else {
                reply(connection, status: "503 Service Unavailable", body: Data(), type: "text/plain")
            }
        default:
            reply(connection, status: "404 Not Found", body: Data(), type: "text/plain")
        }
    }

    private func reply(_ connection: NWConnection, status: String, body: Data, type: String) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        var message = Data(head.utf8)
        message.append(body)
        connection.send(content: message, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func startStream(_ connection: NWConnection) {
        let head = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n"
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        let client = Client(connection)
        client.busy = true
        clients[ObjectIdentifier(client)] = client
        updateCount()
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.remove(client)
            default:
                break
            }
        }
        connection.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] error in
            if error != nil {
                self?.remove(client)
            } else {
                client.busy = false
            }
        })
    }

    private func remove(_ client: Client) {
        queue.async {
            self.clients[ObjectIdentifier(client)] = nil
            client.connection.cancel()
            self.updateCount()
        }
    }

    private func updateCount() {
        stateLock.lock()
        viewerCount = clients.count
        stateLock.unlock()
    }
}
