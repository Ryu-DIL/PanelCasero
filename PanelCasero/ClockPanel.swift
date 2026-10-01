import SwiftUI

struct ClockPanel: View {
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
        ZStack(alignment: .topTrailing) {
            // Solo se actualiza una vez por minuto para gastar poca batería.
            TimelineView(.everyMinute) { context in
                VStack(spacing: 2) {
                    Text(Self.timeFormatter.string(from: context.date))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(Self.dateFormatter.string(from: context.date))
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .padding(6)
            }
            .foregroundColor(.secondary)
        }
        .card()
    }
}
