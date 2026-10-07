import SwiftUI

/// Teclado numérico para meter el PIN (compacto, cabe en horizontal en el 6s).
struct PINPadView: View {
    let title: String
    let length: Int
    /// Devuelve true si el PIN es correcto.
    let onComplete: (String) -> Bool
    var onCancel: (() -> Void)? = nil

    @EnvironmentObject var settings: AppSettings
    @State private var digits = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 10) {
            Text(wrong ? settings.t("pin_wrong") : title)
                .font(.label(14, weight: .semibold))
                .foregroundColor(wrong ? Theme.signal : Theme.text)
            HStack(spacing: 12) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .strokeBorder(wrong ? Theme.signal : Theme.textMuted, lineWidth: 1.5)
                        .background(Circle().fill(index < digits.count ? Theme.text : Color.clear))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(height: 14)
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { column in
                            key(row, column)
                        }
                    }
                }
            }
            if let onCancel = onCancel {
                Button(settings.t("cancel"), action: onCancel)
                    .font(.label(13))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    private func label(_ row: Int, _ column: Int) -> String {
        if row < 3 { return "\(row * 3 + column + 1)" }
        switch column {
        case 0: return ""
        case 1: return "0"
        default: return "⌫"
        }
    }

    @ViewBuilder
    private func key(_ row: Int, _ column: Int) -> some View {
        let text = label(row, column)
        if text.isEmpty {
            Color.clear.frame(width: 50, height: 50)
        } else {
            Button(action: { press(text) }) {
                Text(text)
                    .font(.numeral(text == "⌫" ? 20 : 24, weight: .regular))
                    .foregroundColor(Theme.text)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func press(_ key: String) {
        wrong = false
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        guard digits.count < length else { return }
        digits += key
        if digits.count == length {
            let correct = onComplete(digits)
            digits = ""
            if !correct {
                wrong = true
            }
        }
    }
}
