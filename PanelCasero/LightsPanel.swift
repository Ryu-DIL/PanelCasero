import SwiftUI

struct LightRef: Identifiable {
    let id: String
}

/// Dos luces: toque = encender/apagar, mantener pulsado = color y brillo.
struct LightsPanel: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var favorites: FavoritesStore
    @State private var detail: LightRef? = nil

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppSettings.lightIDs, id: \.self) { id in
                LightButton(title: settings.lightName(id),
                            icon: settings.lightIcon(id),
                            subtitle: subtitle(id),
                            state: store.lights[id],
                            toggle: { toggle(id) },
                            openDetail: { openDetail(id) })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $detail) { ref in
            LightDetailView(lightID: ref.id)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(favorites)
                .preferredColorScheme(settings.colorScheme)
        }
    }

    private func subtitle(_ id: String) -> String {
        switch store.status {
        case .notConfigured, .unauthorized, .unreachable:
            return settings.t("no_server")
        case .connected:
            guard let light = store.lights[id], light.online else {
                return settings.t("offline")
            }
            return light.on ? settings.t("on") : settings.t("off")
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

private struct LightButton: View {
    let title: String
    let icon: String
    let subtitle: String
    let state: LightState?
    let toggle: () -> Void
    let openDetail: () -> Void

    private var isOn: Bool {
        guard let state = state else { return false }
        return state.online && state.on
    }

    private var isOffline: Bool {
        guard let state = state else { return true }
        return !state.online
    }

    /// Color del botón cuando la luz está encendida (el color real de la luz).
    private var onColor: Color {
        guard let state = state else { return Color.yellow }
        if state.mode == "colour" {
            return Color(hue: state.hue / 360.0, saturation: max(0.35, state.saturation / 100.0), brightness: 1)
        }
        // Blanco: de cálido (amarillo-naranja) a frío (casi blanco azulado).
        let warmth = 1 - state.temperature / 100.0
        return Color(hue: 0.12, saturation: 0.15 + 0.45 * warmth, brightness: 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 26))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11))
                .opacity(0.8)
                .lineLimit(1)
        }
        .foregroundColor(isOn ? Color.black : Color.primary)
        .opacity(isOffline ? 0.5 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isOn ? onColor : Color(.secondarySystemBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .onLongPressGesture(minimumDuration: 0.5) { openDetail() }
    }
}
