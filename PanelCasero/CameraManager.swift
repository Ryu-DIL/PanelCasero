import AVFoundation
import SwiftUI

/// Gestiona la cámara frontal: vista previa y detección de movimiento.
/// Usa poca resolución (640×480) y 15 fotogramas por segundo para gastar
/// poca batería y no calentar el iPhone.
final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum State {
        case idle, running, denied, unavailable
    }

    @Published private(set) var state: State = .idle
    /// Cantidad de movimiento reciente (0...1), para el indicador de Ajustes.
    @Published private(set) var motionScore: Double = 0
    /// true mientras hay movimiento sostenido.
    @Published private(set) var motionActive = false

    let session = AVCaptureSession()

    /// Se llama (en la cola de la cámara) cada vez que se detecta movimiento.
    var onMotion: (() -> Void)?

    private let queue = DispatchQueue(label: "panelcasero.camera")
    private let analyzer = MotionAnalyzer()
    private var configured = false
    private var frameCount = 0
    private var lastPublish = Date.distantPast

    /// Segundos que se ignora la cámara mientras la imagen se adapta a un cambio de luz.
    private let settleSeconds: TimeInterval = 2.0
    /// Solo se lee y escribe desde `queue`.
    private var lightChangeCountsAsMotion = false

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
            self.analyzer.reset()
            DispatchQueue.main.async {
                self.state = .idle
                self.motionActive = false
                self.motionScore = 0
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
            DispatchQueue.main.async { self.state = .running }
        }
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
        // Se analiza 1 de cada 3 fotogramas (unos 5 por segundo).
        frameCount += 1
        guard frameCount % 3 == 0,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

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
            DispatchQueue.main.async { [weak self] in
                self?.motionScore = result.score
                self?.motionActive = result.moving
            }
        }
    }
}

// MARK: - Vista previa

/// Vista de UIKit que muestra lo que ve la cámara.
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

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
        guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
        let orientation = window?.windowScene?.interfaceOrientation ?? .portrait
        switch orientation {
        case .landscapeLeft: connection.videoOrientation = .landscapeLeft
        case .landscapeRight: connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
        default: connection.videoOrientation = .portrait
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Cambia cuando la cámara arranca, para recalcular la orientación.
    let running: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.updateOrientation()
    }
}
