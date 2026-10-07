import SwiftUI

/// Rueda de color: el ángulo es el tono y la distancia al centro, la saturación.
struct ColorWheel: View {
    let hue: Double          // 0...360
    let saturation: Double   // 0...100
    let onPick: (Double, Double) -> Void
    let onEditing: (Bool) -> Void

    private static let rainbow: [Color] = stride(from: 0, through: 360, by: 30).map { degrees in
        Color(hue: Double(degrees) / 360.0, saturation: 1, brightness: 1)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let angle = hue * Double.pi / 180
            let distance = CGFloat(saturation / 100) * radius

            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: Self.rainbow), center: .center))
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
                                         center: .center, startRadius: 0, endRadius: radius))
                Circle()
                    .strokeBorder(Theme.hairline, lineWidth: 1)
                Circle()
                    .fill(Color(hue: hue / 360.0, saturation: saturation / 100.0, brightness: 1))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1).padding(-1))
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
                    .position(x: radius + CGFloat(cos(angle)) * distance,
                              y: radius + CGFloat(sin(angle)) * distance)
            }
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onEditing(true)
                        let dx = Double(value.location.x - radius)
                        let dy = Double(value.location.y - radius)
                        var degrees = atan2(dy, dx) * 180 / Double.pi
                        if degrees < 0 { degrees += 360 }
                        let sat = min(1.0, (dx * dx + dy * dy).squareRoot() / Double(radius)) * 100
                        onPick(degrees, sat)
                    }
                    .onEnded { _ in onEditing(false) }
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
