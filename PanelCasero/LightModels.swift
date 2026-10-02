import Foundation

/// Estado de una luz tal y como lo devuelve el servidor.
struct LightState: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: String
    var online: Bool
    var on: Bool
    var mode: String?
    var brightness: Double      // 1...100
    var temperature: Double     // 0 (cálido) ... 100 (frío)
    var hue: Double             // 0...360
    var saturation: Double      // 0...100
    var supportsColor: Bool
    var supportsWhite: Bool
    var supportsWhiteTemp: Bool
    var error: String?
}

/// Órdenes que se pueden enviar a una luz.
enum LightCommand {
    case power(Bool)
    case color(hue: Double, saturation: Double, brightness: Double)
    case white(brightness: Double, temperature: Double)
}

enum LightsError: Error {
    case unauthorized
    case unreachable
    case server(Int, String)
}
