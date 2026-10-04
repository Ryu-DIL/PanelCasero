import AVFoundation

/// Graba un clip corto de vídeo (H.264) con los fotogramas que le pasan.
/// Se usa siempre desde la cola de la cámara.
final class ClipRecorder {
    let duration: Double
    private(set) var isRecording = false

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var startTime: CMTime?

    init(duration: Double = 5) {
        self.duration = duration
    }

    /// Prepara el archivo. Devuelve false si no se pudo.
    func begin(to url: URL, width: Int, height: Int) -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 900_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 15
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        self.writer = writer
        self.input = input
        startTime = nil
        isRecording = true
        return true
    }

    /// Añade un fotograma. Cuando se cumple la duración, cierra el archivo y llama a `completion`.
    func append(_ sample: CMSampleBuffer, completion: @escaping (Bool) -> Void) {
        guard isRecording, let writer = writer, let input = input else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        if startTime == nil {
            writer.startSession(atSourceTime: time)
            startTime = time
        }
        guard let start = startTime else { return }

        if CMTimeGetSeconds(CMTimeSubtract(time, start)) >= duration {
            finish(completion)
            return
        }
        if input.isReadyForMoreMediaData {
            input.append(sample)
        }
    }

    /// Cancela una grabación en curso (por ejemplo, si se para la cámara).
    func cancel() {
        guard isRecording else { return }
        isRecording = false
        writer?.cancelWriting()
        writer = nil
        input = nil
        startTime = nil
    }

    private func finish(_ completion: @escaping (Bool) -> Void) {
        guard let writer = writer, let input = input else {
            completion(false)
            return
        }
        isRecording = false
        self.writer = nil
        self.input = nil
        startTime = nil
        input.markAsFinished()
        writer.finishWriting {
            completion(writer.status == .completed)
        }
    }
}
