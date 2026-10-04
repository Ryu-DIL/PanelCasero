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
        VStack(spacing: 8) {
            Text(wrong ? settings.t("pin_wrong") : title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(wrong ? Color.red : Color.primary)
            HStack(spacing: 12) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .stroke(Color.primary, lineWidth: 1.5)
                        .background(Circle().fill(index < digits.count ? Color.primary : Color.clear))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 2)
            VStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { column in
                            key(row, column)
                        }
                    }
                }
            }
            if let onCancel = onCancel {
                Button(settings.t("cancel"), action: onCancel)
                    .font(.system(size: 14))
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
            Color.clear.frame(width: 48, height: 48)
        } else {
            Button(action: { press(text) }) {
                Text(text)
                    .font(.system(size: 21))
                    .foregroundColor(Color.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
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
