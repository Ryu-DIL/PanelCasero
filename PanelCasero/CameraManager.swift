import AVFoundation
import SwiftUI

/// Gestiona la cámara frontal: vista previa, detección de movimiento, grabación de
/// eventos (foto + clip de 5 s) y directo para el servidor.
/// Usa poca resolución (640×480) y 15 fotogramas por segundo para gastar
/// poca batería y no calentar el iPhone.
final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum State {
        case idle, running, denied, unavailable
    }

    @Published private(set) var state: State = .idle
    /// true mientras hay movimiento sostenido.
    @Published private(set) var motionActive = false
    /// true si el iPhone está caliente y la cámara trabaja a medio gas para enfriarse.
    @Published private(set) var reducedMode = false

    let session = AVCaptureSession()

    /// Se llama (en la cola de la cámara) cada vez que se detecta movimiento.
    var onMotion: (() -> Void)?
    /// Se llama (en el hilo principal) cuando hay un evento nuevo o un clip terminado.
    var onEventsChanged: (() -> Void)?

    private let queue = DispatchQueue(label: "panelcasero.camera")
    private let analyzer = MotionAnalyzer()
    private let encoder = FrameEncoder()
    private let recorder = ClipRecorder(duration: 5)

    // Todo lo siguiente se usa solo desde `queue`.
    private var configured = false
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoOrientation: AVCaptureVideoOrientation = .portrait      // la que se quiere
    private var appliedOrientation: AVCaptureVideoOrientation?                // la que tiene la cámara
    private var frameCount = 0
    private var lastPublish = Date.distantPast
    private var lastStreamFrame = Date.distantPast
    private var pendingEvent: (id: String, kind: String, created: Date, hold: Bool, reason: String?)?
    private var recordingEventID: String?
    private var lightChangeCountsAsMotion = false
    /// 0 = normal, 1 = iPhone caliente, 2 = iPhone muy caliente.
    private var loadLevel = 0
    /// Vigilante: si la cámara deja de dar imágenes (llamada, otra app, error), se reinicia sola.
    private var wantsRunning = false
    private var lastFrameAt = Date()
    private var watchdog: DispatchSourceTimer?

    /// Segundos que se ignora la cámara mientras la imagen se adapta a un cambio de luz.
    private let settleSeconds: TimeInterval = 2.0

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(thermalChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        applyThermalState()
    }

    @objc private func thermalChanged() {
        applyThermalState()
    }

    /// Si el iPhone se calienta, se analizan menos imágenes y se manda menos directo.
    private func applyThermalState() {
        let level: Int
        switch ProcessInfo.processInfo.thermalState {
        case .serious: level = 1
        case .critical: level = 2
        default: level = 0
        }
        queue.async { [weak self] in
            self?.loadLevel = level
        }
        let reduced = level > 0
        DispatchQueue.main.async { [weak self] in
            if self?.reducedMode != reduced { self?.reducedMode = reduced }
        }
    }

    // MARK: - Ajustes

    func setSensitivity(_ value: Int) {
        queue.async { [analyzer] in
            analyzer.sensitivity = value
        }
    }

    func setLightChangeCountsAsMotion(_ value: Bool) {
        queue.async { [weak self] in
            self?.lightChangeCountsAsMotion = value
        }
    }

    /// Orientación con la que se guardan las fotos, los clips y el directo.
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        queue.async { [weak self] in
            guard let self = self, orientation != self.videoOrientation else { return }
            self.videoOrientation = orientation
            // Se espera a que termine el giro de la pantalla antes de tocar la cámara.
            self.queue.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.applyOrientation()
            }
        }
    }

    private func applyOrientation() {
        guard appliedOrientation != videoOrientation,
              let connection = videoOutput?.connection(with: .video),
              connection.isVideoOrientationSupported else { return }
        // No se gira a mitad de un clip: se reintenta un poco después.
        if recorder.isRecording || pendingEvent != nil {
            queue.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.applyOrientation()
            }
            return
        }
        session.beginConfiguration()
        connection.videoOrientation = videoOrientation
        session.commitConfiguration()
        appliedOrientation = videoOrientation
        analyzer.reset()
    }

    // MARK: - Eventos

    /// Pide una foto y un clip de 5 s ahora mismo (alarma o prueba).
    /// Con `hold` el evento se guarda pero no se envía hasta que alguien lo libere.
    /// Se ignora si ya se está grabando otro.
    func captureEvent(id: String = UUID().uuidString.lowercased(), kind: String,
                      hold: Bool = false, reason: String? = nil) {
        queue.async { [weak self] in
            guard let self = self, self.session.isRunning,
                  self.pendingEvent == nil, !self.recorder.isRecording else { return }
            self.pendingEvent = (id, kind, Date(), hold, reason)
        }
    }

    private func startEvent(_ request: (id: String, kind: String, created: Date, hold: Bool, reason: String?),
                            sample: CMSampleBuffer, buffer: CVPixelBuffer) {
        guard let jpeg = encoder.jpeg(from: buffer, quality: 0.75) else { return }
        EventStorage.begin(id: request.id, kind: request.kind, created: request.created, jpeg: jpeg,
                           held: request.hold, reason: request.reason)

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        if recorder.begin(to: EventStorage.clipURL(request.id), width: width, height: height) {
            recordingEventID = request.id
            appendToClip(sample)
        } else {
            EventStorage.update(request.id) { $0.clipExpected = false }
        }
        notifyEventsChanged()
    }

    private func appendToClip(_ sample: CMSampleBuffer) {
        guard let id = recordingEventID else { return }
        recorder.append(sample) { [weak self] success in
            self?.queue.async {
                EventStorage.update(id) { event in
                    if success { event.clipReady = true } else { event.clipExpected = false }
                }
                if self?.recordingEventID == id { self?.recordingEventID = nil }
                self?.notifyEventsChanged()
            }
        }
    }

    private func notifyEventsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onEventsChanged?()
        }
    }

    // MARK: - Arranque y parada

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startSession()
                } else {
                    DispatchQueue.main.async { self?.state = .denied }
                }
            }
        default:
            DispatchQueue.main.async { self.state = .denied }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if self.recorder.isRecording, let id = self.recordingEventID {
                self.recorder.cancel()
                EventStorage.update(id) { $0.clipExpected = false }
                self.recordingEventID = nil
            }
            self.pendingEvent = nil
            self.analyzer.reset()
            self.wantsRunning = false
            self.stopWatchdog()
            DispatchQueue.main.async {
                self.state = .idle
                if self.motionActive { self.motionActive = false }
                MotionMeter.shared.set(0)
            }
        }
    }

    private func startSession() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if !self.configured {
                self.configured = self.configure()
            }
            guard self.configured else {
                DispatchQueue.main.async { self.state = .unavailable }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.wantsRunning = true
            self.lastFrameAt = Date()
            self.startWatchdog()
            DispatchQueue.main.async { self.state = .running }
        }
    }

    private func startWatchdog() {
        guard watchdog == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.restartIfStalled()
        }
        timer.resume()
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private func restartIfStalled() {
        guard wantsRunning, configured else { return }
        let stalled = Date().timeIntervalSince(lastFrameAt) > 10
        guard !session.isRunning || stalled else { return }
        session.stopRunning()
        lastFrameAt = Date()
        analyzer.reset()
        session.startRunning()
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        videoOutput = output
        applyOrientation()

        // 15 fotogramas por segundo (si el formato lo permite).
        let supports15 = device.activeFormat.videoSupportedFrameRateRanges.contains {
            $0.minFrameRate <= 15 && $0.maxFrameRate >= 15
        }
        if supports15, (try? device.lockForConfiguration()) != nil {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            device.unlockForConfiguration()
        }
        return true
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCount += 1
        lastFrameAt = Date()

        // 1. Clip en grabación.
        if recorder.isRecording {
            appendToClip(sampleBuffer)
        }

        // 2. Evento pedido: foto ahora y empieza el clip.
        if let request = pendingEvent {
            pendingEvent = nil
            startEvent(request, sample: sampleBuffer, buffer: buffer)
        }

        // 3. Directo: pocas imágenes por segundo si nadie mira, más si hay espectadores.
        publishStreamFrame(buffer)

        // 4. Detección de movimiento: 1 de cada 3 fotogramas (unos 5 por segundo);
        //    con el iPhone caliente, 1 de cada 6 o de cada 9.
        let analysisEvery = [3, 6, 9][min(loadLevel, 2)]
        guard frameCount % analysisEvery == 0 else { return }

        // Si la luz acaba de cambiar por una causa conocida (brillo de la pantalla,
        // una luz que ha encendido la propia app...), se descarta la imagen.
        if MotionGuard.shared.isSuppressed {
            analyzer.reset()
            return
        }

        let result = analyzer.analyze(buffer)

        if result.lightChanged {
            // Cambio brusco de luz en toda la imagen: la cámara tarda un momento
            // en adaptar la exposición, así que se ignora un par de segundos.
            MotionGuard.shared.suppress(for: settleSeconds)
            if lightChangeCountsAsMotion {
                BrightnessController.shared.motionDetected()
                onMotion?()
            }
            return
        }

        if result.moving {
            BrightnessController.shared.motionDetected()
            onMotion?()
        }

        let now = Date()
        if now.timeIntervalSince(lastPublish) >= 0.25 {
            lastPublish = now
            let score = result.score
            let moving = result.moving
            DispatchQueue.main.async { [weak self] in
                MotionMeter.shared.set(score)
                if self?.motionActive != moving { self?.motionActive = moving }
            }
        }
    }

    private func publishStreamFrame(_ buffer: CVPixelBuffer) {
        let server = StreamServer.shared
        let watching = server.hasClients
        let slowdown = [1.0, 2.5, 6.0][min(loadLevel, 2)]
        let interval: TimeInterval = (watching ? 0.16 : 1.0) * slowdown   // ~6 imágenes/s o 1 imagen/s
        let now = Date()
        guard now.timeIntervalSince(lastStreamFrame) >= interval else { return }
        lastStreamFrame = now
        if let jpeg = encoder.jpeg(from: buffer, quality: watching ? 0.5 : 0.6) {
            server.publish(jpeg)
        }
    }
}

// MARK: - Vista previa

/// Vista de UIKit que muestra lo que ve la cámara.
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    /// Se avisa cuando cambia la orientación de la pantalla.
    var onOrientation: ((AVCaptureVideoOrientation) -> Void)?

    private var previewOrientation: AVCaptureVideoOrientation?
    private var reportedOrientation: AVCaptureVideoOrientation?

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass garantiza el tipo.
        return layer as! AVCaptureVideoPreviewLayer // swiftlint:disable:this force_cast
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    /// Gira la imagen según la orientación de la pantalla.
    func updateOrientation() {
        let interface = window?.windowScene?.interfaceOrientation ?? .portrait
        let orientation: AVCaptureVideoOrientation
        switch interface {
        case .landscapeLeft: orientation = .landscapeLeft
        case .landscapeRight: orientation = .landscapeRight
        case .portraitUpsideDown: orientation = .portraitUpsideDown
        default: orientation = .portrait
        }
        // Solo se toca la cámara cuando la orientación cambia de verdad: esta función se llama
        // en cada pasada de maquetación y cambiar la orientación de la conexión es caro.
        if previewOrientation != orientation,
           let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
            previewOrientation = orientation
        }
        if reportedOrientation != orientation {
            reportedOrientation = orientation
            onOrientation?(orientation)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Cambia cuando la cámara arranca, para recalcular la orientación.
    let running: Bool
    let onOrientation: (AVCaptureVideoOrientation) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onOrientation = onOrientation
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onOrientation = onOrientation
        uiView.updateOrientation()
    }
}
