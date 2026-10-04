import SwiftUI

/// La alarma. Estados:
///   disarmed -> (candado) -> exiting (60 s para salir, sin mostrar cuenta atrás) -> armed
///   armed + movimiento -> entry: se guarda foto y clip, pero NO se avisa; hay 60 s para el PIN
///   entry + PIN correcto -> disarmed (el evento retenido se borra)
///   entry + 60 s sin PIN, o 3 PIN erróneos -> alerta: se envía el evento y, cuando está enviado, suena la sirena
///   tras una alerta, 2 minutos sin nuevas alertas; sigue armada.
@MainActor
final class AlarmController: ObservableObject {
    enum State: String {
        case disarmed, exiting, armed, entry
    }

    @Published private(set) var state: State
    /// true mientras se muestra el teclado del PIN para desarmar.
    @Published var showingPIN = false
    /// Mensaje breve (por ejemplo, "primero define un PIN").
    @Published private(set) var message: String? = nil

    static let exitSeconds: UInt64 = 60
    static let entrySeconds: UInt64 = 60
    static let pauseSeconds: TimeInterval = 120
    static let maxWrongPINs = 3
    private static let armedKey = "alarmArmed"

    private let settings: AppSettings
    private weak var camera: CameraManager?
    private let link: DeviceLink
    private let siren = SirenPlayer()

    private var exitTask: Task<Void, Never>?
    private var entryTask: Task<Void, Never>?
    private var sirenTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var heldEventID: String?
    private var sirenEventID: String?
    private var pauseUntil = Date.distantPast
    private var wrongPINs = 0

    init(settings: AppSettings, camera: CameraManager, link: DeviceLink) {
        self.settings = settings
        self.camera = camera
        self.link = link
        // Si la app se reinicia (apagón...) estando armada, sigue armada.
        state = UserDefaults.standard.bool(forKey: Self.armedKey) ? .armed : .disarmed
        applyBrightnessRule()
    }

    var isArmed: Bool { state != .disarmed }

    // MARK: - Candado

    func lockTapped() {
        if state == .disarmed {
            guard settings.hasPIN else {
                flash(settings.t("pin_first"))
                return
            }
            arm()
        } else {
            showingPIN = true
        }
    }

    func arm() {
        guard state == .disarmed else { return }
        set(.exiting)
        exitTask?.cancel()
        exitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.exitSeconds * 1_000_000_000)
            guard !Task.isCancelled, let self = self, self.state == .exiting else { return }
            self.set(.armed)
        }
    }

    func disarm() {
        exitTask?.cancel()
        entryTask?.cancel()
        sirenTask?.cancel()
        if let id = heldEventID {
            EventStorage.remove(id)               // entró el dueño: la foto retenida se descarta
            heldEventID = nil
        }
        sirenEventID = nil
        siren.stop()
        wrongPINs = 0
        showingPIN = false
        set(.disarmed)
    }

    // MARK: - Movimiento

    /// Lo llama la cámara cada vez que detecta movimiento.
    func motionDetected() {
        guard state == .armed, Date() >= pauseUntil else { return }
        set(.entry)
        let id = UUID().uuidString.lowercased()
        heldEventID = id
        camera?.captureEvent(id: id, kind: "alert", hold: true, reason: "motion")
        entryTask?.cancel()
        entryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.entrySeconds * 1_000_000_000)
            guard !Task.isCancelled, let self = self, self.state == .entry else { return }
            self.triggerAlert(reason: "motion")
        }
    }

    // MARK: - PIN

    /// Comprueba un PIN. Con la alarma armada, 3 errores seguidos disparan la alerta.
    func checkPIN(_ pin: String) -> Bool {
        if settings.verifyPIN(pin) {
            wrongPINs = 0
            return true
        }
        wrongPINs += 1
        if wrongPINs >= Self.maxWrongPINs {
            wrongPINs = 0
            if isArmed && Date() >= pauseUntil {
                triggerAlert(reason: "pin")
            }
        }
        return false
    }

    // MARK: - Alerta

    private func triggerAlert(reason: String) {
        entryTask?.cancel()
        pauseUntil = Date().addingTimeInterval(Self.pauseSeconds)
        let id = heldEventID ?? UUID().uuidString.lowercased()
        heldEventID = nil

        if EventStorage.exists(id) {
            // Se libera la foto y el clip que se guardaron al detectar el movimiento.
            EventStorage.update(id) { event in
                event.held = nil
                if reason == "pin" { event.reason = "pin" }
            }
            link.kick()
        } else {
            camera?.captureEvent(id: id, kind: "alert", hold: false, reason: reason)
        }

        // La sirena suena cuando el aviso ya está enviado; si no hay conexión, a los 15 s.
        sirenEventID = id
        sirenTask?.cancel()
        sirenTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, let self = self else { return }
            self.startSirenIfNeeded(for: id)
        }
        if state == .entry { set(.armed) }
    }

    /// La foto del evento ya está en el servidor (el servidor avisa al móvil).
    func photoUploaded(_ id: String) {
        startSirenIfNeeded(for: id)
    }

    private func startSirenIfNeeded(for id: String) {
        guard sirenEventID == id, isArmed else { return }
        sirenEventID = nil
        sirenTask?.cancel()
        siren.play(seconds: settings.sirenSeconds)
    }

    // MARK: - Órdenes desde el móvil (web)

    /// Atiende "arm", "disarm" o "state" del servidor. Devuelve el estado resultante.
    func handleRemote(_ action: String) -> String {
        switch action {
        case "arm":
            if settings.hasPIN { arm() }
        case "disarm":
            disarm()
        default:
            break
        }
        return state.rawValue
    }

    // MARK: - Interno

    private func set(_ new: State) {
        state = new
        UserDefaults.standard.set(new != .disarmed, forKey: Self.armedKey)
        applyBrightnessRule()
        link.sendHeartbeatSoon()
    }

    /// Armada, el movimiento no sube el brillo de la pantalla.
    private func applyBrightnessRule() {
        BrightnessController.shared.motionRaisesBrightness = (state == .disarmed)
    }

    private func flash(_ text: String) {
        message = text
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
