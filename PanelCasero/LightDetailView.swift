import SwiftUI

/// Ventana de color y brillo de una luz (se abre manteniendo pulsado su botón).
struct LightDetailView: View {
    let lightID: String

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var favorites: FavoritesStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var adjusting = false
    @State private var favoriteToDelete: FavoriteColor? = nil

    var body: some View {
        NavigationView {
            Group {
                if let light = store.lights[lightID] {
                    content(light)
                } else {
                    Text(settings.t("no_server"))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(settings.lightName(lightID))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("close")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(adjusting)
        .confirmationDialog(settings.t("delete_favorite"),
                            isPresented: Binding(get: { favoriteToDelete != nil },
                                                 set: { if !$0 { favoriteToDelete = nil } }),
                            titleVisibility: .visible) {
            Button(settings.t("delete"), role: .destructive) {
                if let favorite = favoriteToDelete { favorites.remove(favorite) }
                favoriteToDelete = nil
            }
            Button(settings.t("cancel"), role: .cancel) { favoriteToDelete = nil }
        }
    }

    // MARK: - Diseño

    private func content(_ light: LightState) -> some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(alignment: .center, spacing: 16) {
                    wheel(light)
                        .frame(width: max(100, min(geo.size.height - 16, geo.size.width * 0.42)))
                    controls(light)
                }
                .padding(12)
            } else {
                VStack(spacing: 12) {
                    wheel(light)
                        .frame(height: max(100, min(geo.size.width - 40, geo.size.height * 0.42)))
                    controls(light)
                }
                .padding(12)
            }
        }
    }

    private func isWhite(_ light: LightState) -> Bool {
        light.supportsWhite && light.mode == "white"
    }

    private func wheel(_ light: LightState) -> some View {
        ColorWheel(hue: light.hue,
                   saturation: light.saturation,
                   onPick: { hue, saturation in
                       // Tocar la rueda siempre pasa la luz a modo color.
                       let current = store.lights[lightID] ?? light
                       store.send(lightID, .color(hue: hue, saturation: saturation, brightness: current.brightness))
                   },
                   onEditing: { adjusting = $0 })
            .opacity(isWhite(light) ? 0.35 : 1)
            .disabled(!light.supportsColor)
    }

    private func controls(_ light: LightState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(settings.t("power"), isOn: Binding(
                get: { store.lights[lightID]?.on ?? light.on },
                set: { store.send(lightID, .power($0)) }
            ))

            if light.supportsColor && light.supportsWhite {
                Picker("", selection: modeBinding(light)) {
                    Text(settings.t("color")).tag(0)
                    Text(settings.t("white")).tag(1)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t("brightness"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Slider(value: brightnessBinding(light), in: 1...100,
                       onEditingChanged: { adjusting = $0 })
            }

            if isWhite(light) && light.supportsWhiteTemp {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(settings.t("temperature"))
                        Spacer()
                        Text("\(settings.t("warm")) ↔ \(settings.t("cool"))")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    Slider(value: temperatureBinding(light), in: 0...100,
                           onEditingChanged: { adjusting = $0 })
                }
            }

            if light.supportsColor {
                favoritesRow(light)
            }

            if !light.online {
                Text(settings.t("offline"))
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Enlaces con el estado

    private func modeBinding(_ light: LightState) -> Binding<Int> {
        Binding(
            get: { isWhite(store.lights[lightID] ?? light) ? 1 : 0 },
            set: { index in
                let current = store.lights[lightID] ?? light
                if index == 0 {
                    store.send(lightID, .color(hue: current.hue, saturation: current.saturation,
                                               brightness: current.brightness))
                } else {
                    store.send(lightID, .white(brightness: current.brightness,
                                               temperature: current.temperature))
                }
            }
        )
    }

    private func brightnessBinding(_ light: LightState) -> Binding<Double> {
        Binding(
            get: { store.lights[lightID]?.brightness ?? light.brightness },
            set: { value in
                let current = store.lights[lightID] ?? light
                if isWhite(current) {
                    store.send(lightID, .white(brightness: value, temperature: current.temperature))
                } else {
                    store.send(lightID, .color(hue: current.hue, saturation: current.saturation,
                                               brightness: value))
                }
            }
        )
    }

    private func temperatureBinding(_ light: LightState) -> Binding<Double> {
        Binding(
            get: { store.lights[lightID]?.temperature ?? light.temperature },
            set: { value in
                let current = store.lights[lightID] ?? light
                store.send(lightID, .white(brightness: current.brightness, temperature: value))
            }
        )
    }

    // MARK: - Favoritos

    private func favoritesRow(_ light: LightState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settings.t("favorites"))
                .font(.footnote)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button(action: { addFavorite(light) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    ForEach(favorites.items) { favorite in
                        Circle()
                            .fill(Color(hue: favorite.hue / 360.0,
                                        saturation: favorite.saturation / 100.0,
                                        brightness: 1))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                            .onTapGesture {
                                store.send(lightID, .color(hue: favorite.hue,
                                                           saturation: favorite.saturation,
                                                           brightness: favorite.brightness))
                            }
                            .onLongPressGesture(minimumDuration: 0.6) {
                                favoriteToDelete = favorite
                            }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func addFavorite(_ light: LightState) {
        let current = store.lights[lightID] ?? light
        favorites.add(hue: current.hue, saturation: current.saturation, brightness: current.brightness)
    }
}
