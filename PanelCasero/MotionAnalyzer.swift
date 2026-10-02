import CoreVideo

/// Detecta movimiento comparando fotogramas muy reducidos (rejilla de 32×24)
/// con el fotograma anterior y con un "fondo" que se actualiza despacio.
/// Se usa siempre desde la misma cola de la cámara, por eso no necesita bloqueos.
final class MotionAnalyzer {
    static let cols = 32
    static let rows = 24

    struct Result {
        let score: Double   // 0...1, para el indicador de Ajustes
        let moving: Bool    // true cuando hay movimiento sostenido
    }

    /// 1 (poco sensible) ... 10 (muy sensible).
    var sensitivity = 5 {
        didSet { sensitivity = min(10, max(1, sensitivity)) }
    }

    /// Cuánto se mezcla cada fotograma en el fondo (0.05 = se adapta en unos 4 s).
    private static let backgroundRate: Float = 0.05

    private var previous: [Float] = []
    private var background: [Float] = []
    private var streak = 0

    /// Diferencia de brillo (0...255) que debe cambiar una celda para contar.
    private var lumaThreshold: Float { 24 - 1.8 * Float(sensitivity) }
    /// Fracción de celdas que deben cambiar para considerar que hay movimiento.
    private var minFraction: Double { 0.06 - 0.005 * Double(sensitivity) }

    /// Olvida lo aprendido (por ejemplo tras un cambio de brillo de pantalla).
    func reset() {
        previous = []
        background = []
        streak = 0
    }

    func analyze(_ buffer: CVPixelBuffer) -> Result {
        guard var current = grid(from: buffer) else {
            return Result(score: 0, moving: false)
        }
        // Se resta el brillo medio para ignorar cambios de luz generales
        // (autoexposición, la propia pantalla, nubes...).
        let mean = current.reduce(0, +) / Float(current.count)
        for index in current.indices {
            current[index] -= mean
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
        let limit = lumaThreshold
        var changed = 0
        for index in current.indices {
            let againstBackground = abs(current[index] - background[index])
            let againstPrevious = abs(current[index] - previous[index])
            if max(againstBackground, againstPrevious) > limit {
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
