import AVFoundation
import MediaPlayer
import UIKit

/// Sirena de disuasión: suena tras enviar la alerta, durante unos segundos.
final class SirenPlayer {
    private var player: AVAudioPlayer?
    private var stopWork: DispatchWorkItem?

    /// Hace sonar la sirena `seconds` segundos (0 = no suena). Suena aunque el móvil esté en silencio.
    func play(seconds: Int) {
        guard seconds > 0 else { return }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.sirenWAV)
            player.numberOfLoops = -1
            player.volume = 1.0
            self.player = player
            Self.setSystemVolume(1.0)
            player.play()
        } catch {
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds), execute: work)
    }

    func stop() {
        stopWork?.cancel()
        stopWork = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Volumen

    /// Sube el volumen del sistema (iOS no ofrece otra forma que el control de volumen oculto).
    private static func setSystemVolume(_ value: Float) {
        DispatchQueue.main.async {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first
            guard let window = window else { return }
            let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
            window.addSubview(view)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                view.subviews.compactMap { $0 as? UISlider }.first?.value = value
                view.removeFromSuperview()
            }
        }
    }

    // MARK: - El sonido (se genera, no hay archivos)

    /// Dos segundos de sirena: el tono sube de 700 a 1300 Hz y vuelve a bajar.
    private static let sirenWAV: Data = {
        let sampleRate = 22050
        let cycle = 2.0
        let count = Int(Double(sampleRate) * cycle)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        var phase = 0.0
        for index in 0..<count {
            let t = Double(index) / Double(sampleRate)
            let x = t < cycle / 2 ? t : cycle - t
            let frequency = 700.0 + 600.0 * x
            phase += 2.0 * Double.pi * frequency / Double(sampleRate)
            samples.append(Int16(sin(phase) * 0.9 * Double(Int16.max)))
        }
        return wavData(samples, sampleRate: sampleRate)
    }()

    private static func wavData(_ samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        func put32(_ value: UInt32) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 4))
        }
        func put16(_ value: UInt16) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 2))
        }
        let byteCount = UInt32(samples.count * 2)
        data.append(Data("RIFF".utf8))
        put32(36 + byteCount)
        data.append(Data("WAVE".utf8))
        data.append(Data("fmt ".utf8))
        put32(16)                          // tamaño del bloque
        put16(1)                           // PCM
        put16(1)                           // mono
        put32(UInt32(sampleRate))
        put32(UInt32(sampleRate * 2))      // bytes por segundo
        put16(2)                           // bytes por muestra
        put16(16)                          // bits por muestra
        data.append(Data("data".utf8))
        put32(byteCount)
        for sample in samples {
            put16(UInt16(bitPattern: sample))
        }
        return data
    }
}
