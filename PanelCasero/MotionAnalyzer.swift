import CoreVideo

/// Detecta movimiento comparando fotogramas muy reducidos (rejilla de 32×24)
/// con el fotograma anterior y con un "fondo" que se actualiza despacio.
///
/// Cada celda se mide RELATIVA al brillo medio de la imagen (no en valores absolutos):
/// así la autoexposición de la cámara (que sube o baja la ganancia cuando la pantalla
/// cambia de brillo) no se confunde con movimiento. Además, el umbral se adapta al
/// ruido medido, para que de noche no salten falsos avisos.
/// Se usa siempre desde la misma cola de la cámara, por eso no necesita bloqueos.
final class MotionAnalyzer {
    static let cols = 32
    static let rows = 24

    struct Result {
        let score: Double   // 0...1, para el indicador de Ajustes
        let moving: Bool    // true cuando hay movimiento sostenido
        var lightChanged = false  // true si la luz de toda la imagen cambió de golpe
    }

    /// 1 (poco sensible) ... 10 (muy sensible).
    var sensitivity = 5 {
        didSet { sensitivity = min(10, max(1, sensitivity)) }
    }

    /// Cuánto se mezcla cada fotograma en el fondo (0.05 = se adapta en unos 4 s).
    private static let backgroundRate: Float = 0.05

    /// Un cambio brusco del brillo medio de la imagen se considera cambio de luz
    /// (interruptor, persiana...) y no movimiento: más de 8 niveles y más del 12 %.
    private static let lightJumpAbsolute: Float = 8
    private static let lightJumpRelative: Float = 0.12

    /// Denominador mínimo al normalizar (evita dividir por casi cero a oscuras).
    private static let minReference: Float = 12
    /// El umbral nunca baja de este múltiplo del ruido típico entre dos fotogramas.
    private static let noiseFactor: Float = 4.5

    private var previous: [Float] = []
    private var background: [Float] = []
    private var previousMean: Float? = nil
    private var streak = 0

    /// Cambio relativo (en % del brillo medio) que debe tener una celda para contar.
    private var baseThreshold: Float { 24 - 1.8 * Float(sensitivity) }
    /// Fracción de celdas que deben cambiar para considerar que hay movimiento.
    private var minFraction: Double { 0.06 - 0.005 * Double(sensitivity) }

    /// Olvida lo aprendido (por ejemplo tras un cambio de brillo de pantalla).
    func reset() {
        previous = []
        background = []
        previousMean = nil
        streak = 0
    }

    func analyze(_ buffer: CVPixelBuffer) -> Result {
        guard var current = grid(from: buffer) else {
            return Result(score: 0, moving: false)
        }
        let mean = current.reduce(0, +) / Float(current.count)

        // ¿Ha cambiado de golpe la luz de toda la imagen?
        var lightJump = false
        if let last = previousMean {
            lightJump = abs(mean - last) > max(Self.lightJumpAbsolute, Self.lightJumpRelative * last)
        }
        previousMean = mean

        // Brillo de cada celda como % del brillo medio: inmune a subidas y bajadas de ganancia.
        let reference = max(mean, Self.minReference)
        for index in current.indices {
            current[index] = current[index] / reference * 100
        }

        if lightJump {
            // Se toma la nueva imagen como referencia y no se avisa de movimiento.
            background = current
            previous = current
            streak = 0
            return Result(score: 0, moving: false, lightChanged: true)
        }

        // Primer fotograma tras un reinicio: solo sirve de referencia.
        guard background.count == current.count, previous.count == current.count else {
            background = current
            previous = current
            streak = 0
            return Result(score: 0, moving: false)
        }

        // Una celda "cambia" si difiere del fotograma anterior (movimiento rápido)
        // o del fondo (movimiento lento o algo que acaba de aparecer).
        var differences = [Float](repeating: 0, count: current.count)
        for index in current.indices {
            differences[index] = abs(current[index] - previous[index])
        }
        // Ruido típico entre dos fotogramas: la mediana apenas se ve afectada por el movimiento.
        let noise = differences.sorted()[differences.count / 2] / 0.6745
        let limit = max(baseThreshold, Self.noiseFactor * noise)

        var changed = 0
        for index in current.indices {
            let againstBackground = abs(current[index] - background[index])
            if max(againstBackground, differences[index]) > limit {
                changed += 1
            }
            background[index] += Self.backgroundRate * (current[index] - background[index])
        }
        previous = current

        let fraction = Double(changed) / Double(current.count)
        let candidate = fraction >= minFraction
        streak = candidate ? streak + 1 : 0
        let score = min(1.0, fraction / (minFraction * 2))
        return Result(score: score, moving: streak >= 2)
    }

    /// Brillo medio de cada celda, leyendo solo el plano de luminancia (Y)
    /// y saltando píxeles para gastar poca CPU.
    private func grid(from buffer: CVPixelBuffer) -> [Float]? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard CVPixelBufferGetPlaneCount(buffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
            return nil
        }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let blockW = width / Self.cols
        let blockH = height / Self.rows
        guard blockW > 0, blockH > 0 else { return nil }

        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var out = [Float](repeating: 0, count: Self.cols * Self.rows)
        for row in 0..<Self.rows {
            for col in 0..<Self.cols {
                var sum = 0
                var count = 0
                var y = row * blockH
                let yEnd = y + blockH
                while y < yEnd {
                    var x = col * blockW
                    let xEnd = x + blockW
                    while x < xEnd {
                        sum += Int(pixels[y * stride + x])
                        count += 1
                        x += 4
                    }
                    y += 4
                }
                out[row * Self.cols + col] = count > 0 ? Float(sum) / Float(count) : 0
            }
        }
        return out
    }
}
