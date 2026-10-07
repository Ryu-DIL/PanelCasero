import SwiftUI

struct LightRef: Identifiable {
    let id: String
}

/// Las luces son lo que se toca: dos losetas que brillan con el color real de cada luz.
/// Toque = encender o apagar; mantener pulsado = color y brillo.
struct LightsPanel: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var favorites: FavoritesStore
    @State private var detail: LightRef? = nil

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppSettings.lightIDs, id: \.self) { id in
                LightTile(title: settings.lightName(id),
                          icon: settings.lightIcon(id),
                          note: note(id),
                          state: store.lights[id],
                          toggle: { toggle(id) },
                          openDetail: { openDetail(id) })
            }
        }
        .sheet(item: $detail) { ref in
            LightDetailView(lightID: ref.id)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(favorites)
                .preferredColorScheme(settings.colorScheme)
        }
    }

    /// Texto que solo aparece cuando algo falla; encendida o apagada ya se ve en la loseta.
    private func note(_ id: String) -> String? {
        switch store.status {
        case .notConfigured, .unauthorized, .unreachable:
            return settings.t("no_server")
        case .connected:
            guard let light = store.lights[id], light.online else {
                return settings.t("offline")
            }
            return nil
        }
    }

    private func toggle(_ id: String) {
        if let light = store.lights[id], light.online {
            store.send(id, .power(!light.on))
        } else {
            Task { await store.refresh() }
        }
    }

    private func openDetail(_ id: String) {
        if store.lights[id] != nil {
            detail = LightRef(id: id)
        }
    }
}

private struct LightTile: View {
    let title: String
    let icon: String
    let note: String?
    let state: LightState?
    let toggle: () -> Void
    let openDetail: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOffline: Bool {
        guard let state = state else { return true }
        return !state.online || note != nil
    }

    private var isOn: Bool {
        guard let state = state, !isOffline else { return false }
        return state.on
    }

    /// El color real de la luz (o ámbar cálido si es blanca).
    private var glow: Color {
        guard let state = state else { return Theme.lamp }
        if state.mode == "colour" {
            return Color(hue: state.hue / 360.0, saturation: max(0.4, state.saturation / 100.0), brightness: 1)
        }
        // Blanco: de cálido (ámbar) a frío (casi blanco azulado).
        let warmth = 1 - state.temperature / 100.0
        return Color(hue: 0.11, saturation: 0.10 + 0.55 * warmth, brightness: 1)
    }

    private var brightness: Double {
        max(0.05, min(1, (state?.brightness ?? 100) / 100))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            tileBackground

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                Spacer(minLength: 4)
                Text(title)
                    .font(.label(14, weight: .semibold))
                    .lineLimit(1)
                if let note = note {
                    Text(note)
                        .font(.label(11))
                        .opacity(0.75)
                        .lineLimit(1)
                }
            }
            .foregroundColor(isOn ? Theme.ink : (isOffline ? Theme.textMuted : Theme.text))
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isOn {
                // El brillo, como una línea fina en el borde inferior.
                GeometryReader { geo in
                    Capsule()
                        .fill(Theme.ink.opacity(0.55))
                        .frame(width: max(8, (geo.size.width - 28) * CGFloat(brightness)), height: 3)
                        .position(x: 14 + max(8, (geo.size.width - 28) * CGFloat(brightness)) / 2,
                                  y: geo.size.height - 9)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .onTapGesture { toggle() }
        .onLongPressGesture(minimumDuration: 0.5) { openDetail() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var tileBackground: some View {
        if isOn {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(LinearGradient(colors: [glow, glow.opacity(0.74)], startPoint: .top, endPoint: .bottom))
                .shadow(color: glow.opacity(0.35), radius: 14, y: 4)
        } else {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                        .strokeBorder(Theme.hairline,
                                      style: StrokeStyle(lineWidth: 1, dash: isOffline ? [4, 4] : []))
                )
        }
    }
}
