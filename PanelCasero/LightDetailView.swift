import SwiftUI

/// Color, brillo y blanco de una luz (se abre manteniendo pulsado su loseta).
struct LightDetailView: View {
    let lightID: String

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LightsStore
    @EnvironmentObject var favorites: FavoritesStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var adjusting = false
    @State private var favoriteToDelete: FavoriteColor? = nil

    private static let warmWhite = Color(red: 1.0, green: 0.74, blue: 0.42)
    private static let coolWhite = Color(red: 0.80, green: 0.88, blue: 1.0)

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let light = store.lights[lightID] {
                    content(light)
                } else {
                    Text(settings.t("no_server"))
                        .font(.label(14))
                        .foregroundColor(Theme.textMuted)
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
        .accentColor(Theme.lamp)
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
                HStack(alignment: .center, spacing: 22) {
                    wheel(light)
                        .frame(width: max(120, min(geo.size.height - 24, geo.size.width * 0.42)))
                    controls(light)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    wheel(light)
                        .frame(height: max(120, min(geo.size.width - 48, geo.size.height * 0.40)))
                    controls(light)
                }
                .padding(16)
            }
        }
    }

    private func isWhite(_ light: LightState) -> Bool {
        light.supportsWhite && light.mode == "white"
    }

    /// Color con el que acaba el recorrido del brillo: el de la luz.
    private func tint(_ light: LightState) -> Color {
        if isWhite(light) {
            let warmth = 1 - light.temperature / 100.0
            return Color(hue: 0.11, saturation: 0.10 + 0.55 * warmth, brightness: 1)
        }
        return Color(hue: light.hue / 360.0, saturation: max(0.35, light.saturation / 100.0), brightness: 1)
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
        let live = store.lights[lightID] ?? light
        return VStack(alignment: .leading, spacing: 14) {
            powerButton(live)

            if light.supportsColor && light.supportsWhite {
                SegmentedChoice(titles: [settings.t("color"), settings.t("white")],
                                selection: modeBinding(light))
            }

            VStack(alignment: .leading, spacing: 6) {
                sliderHeader(settings.t("brightness"), "\(Int(live.brightness.rounded())) %")
                GradientSlider(value: brightnessBinding(light), range: 1...100,
                               colors: [Color.black.opacity(0.9), tint(live)],
                               onEditingChanged: { adjusting = $0 })
            }

            if isWhite(live) && light.supportsWhiteTemp {
                VStack(alignment: .leading, spacing: 6) {
                    sliderHeader(settings.t("temperature"),
                                 "\(settings.t("warm")) ↔ \(settings.t("cool"))")
                    GradientSlider(value: temperatureBinding(light), range: 0...100,
                                   colors: [Self.warmWhite, Self.coolWhite],
                                   onEditingChanged: { adjusting = $0 })
                }
            }

            if light.supportsColor {
                favoritesRow(live)
            }

            if !live.online {
                Text(settings.t("offline"))
                    .font(.label(12))
                    .foregroundColor(Theme.signal)
            }
        }
    }

    private func sliderHeader(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.label(12))
        .foregroundColor(Theme.textMuted)
    }

    private func powerButton(_ light: LightState) -> some View {
        Button(action: { store.send(lightID, .power(!light.on)) }) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                Text(light.on ? settings.t("on") : settings.t("off"))
                    .font(.label(14, weight: .semibold))
            }
            .foregroundColor(light.on ? Theme.ink : Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .fill(light.on ? Theme.lamp : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: light.on ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        VStack(alignment: .leading, spacing: 6) {
            Text(settings.t("favorites"))
                .font(.label(12))
                .foregroundColor(Theme.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button(action: { addFavorite(light) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Theme.textMuted,
                                                           style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(PlainButtonStyle())
                    ForEach(favorites.items) { favorite in
                        let selected = abs(favorite.hue - light.hue) < 4 && abs(favorite.saturation - light.saturation) < 6
                            && light.mode == "colour"
                        Circle()
                            .fill(Color(hue: favorite.hue / 360.0,
                                        saturation: favorite.saturation / 100.0,
                                        brightness: 1))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                            .padding(3)
                            .overlay(Circle().strokeBorder(selected ? Theme.text : Color.clear, lineWidth: 2))
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
