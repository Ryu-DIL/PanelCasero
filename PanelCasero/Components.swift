import SwiftUI

/// Deslizador con el recorrido pintado (por ejemplo, de oscuro al color de la luz).
struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let colors: [Color]
    var onEditingChanged: (Bool) -> Void = { _ in }

    private let thumb: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - thumb)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 12)
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
                    .frame(width: thumb, height: thumb)
                    .offset(x: CGFloat(fraction) * travel)
            }
            .frame(height: thumb)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onEditingChanged(true)
                        let position = min(max(0, drag.location.x - thumb / 2), travel)
                        value = range.lowerBound + Double(position / travel) * span
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
        }
        .frame(height: thumb)
    }
}

/// Selector de dos o más opciones con el aspecto del panel.
struct SegmentedChoice: View {
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button(action: { selection = index }) {
                    Text(title)
                        .font(.label(13, weight: .semibold))
                        .foregroundColor(selection == index ? Theme.ink : Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .fill(selection == index ? Theme.lamp : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .raisedSurface(radius: Theme.radiusMedium)
    }
}
