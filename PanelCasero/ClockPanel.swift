import SwiftUI

/// La hora es lo primero que se mira: tipografía grande y plana, sin tarjeta.
struct ClockPanel: View {
    var compact = false
    var onSettings: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"      // 24 horas
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        HStack(alignment: .top) {
            // Solo se actualiza una vez por minuto para gastar poca batería.
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.timeFormatter.string(from: context.date))
                        .font(.numeral(compact ? 54 : 72))
                        .monospacedDigit()
                        .foregroundColor(Theme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(Self.dateFormatter.string(from: context.date))
                        .font(.label(15))
                        .monospacedDigit()
                        .foregroundColor(Theme.textMuted)
                }
            }
            Spacer(minLength: 0)
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
