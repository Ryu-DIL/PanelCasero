import SwiftUI

/// Dos luces: toque = encender/apagar, mantener pulsado = color y brillo.
/// De momento el estado es solo visual; el control real de Tuya llega en la fase 2.
struct LightsPanel: View {
    @EnvironmentObject var settings: AppSettings
    @State private var bulbOn = false
    @State private var stripOn = false
    @State private var detailFor: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            LightButton(title: settings.t("bulb"),
                        icon: "lightbulb.fill",
                        isOn: bulbOn,
                        onLabel: settings.t("on"),
                        offLabel: settings.t("off"),
                        toggle: { bulbOn.toggle() },
                        openDetail: { detailFor = settings.t("bulb") })
            LightButton(title: settings.t("strip"),
                        icon: "wand.and.rays",
                        isOn: stripOn,
                        onLabel: settings.t("on"),
                        offLabel: settings.t("off"),
                        toggle: { stripOn.toggle() },
                        openDetail: { detailFor = settings.t("strip") })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: Binding(
            get: { detailFor.map { LightDetailItem(name: $0) } },
            set: { detailFor = $0?.name }
        )) { item in
            LightDetailPlaceholder(name: item.name)
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

private struct LightDetailItem: Identifiable {
    let name: String
    var id: String { name }
}

private struct LightButton: View {
    let title: String
    let icon: String
    let isOn: Bool
    let onLabel: String
    let offLabel: String
    let toggle: () -> Void
    let openDetail: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 26))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(isOn ? onLabel : offLabel)
                .font(.system(size: 11))
                .opacity(0.8)
        }
        .foregroundColor(isOn ? .black : .primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isOn ? Color.yellow : Color(.secondarySystemBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .onLongPressGesture(minimumDuration: 0.5) { openDetail() }
    }
}

private struct LightDetailPlaceholder: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode
    let name: String

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text(settings.t("color_bright"))
                    .font(.headline)
                Text(settings.t("coming_soon"))
                    .foregroundColor(.secondary)
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("close")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
