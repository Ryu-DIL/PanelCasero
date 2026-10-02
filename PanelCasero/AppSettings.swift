import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case es, ca, en, de

    var id: String { rawValue }

    /// Nombre del idioma escrito en su propio idioma.
    var displayName: String {
        switch self {
        case .es: return "Español"
        case .ca: return "Valencià"
        case .en: return "English"
        case .de: return "Deutsch"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark, light

    var id: String { rawValue }
}

final class AppSettings: ObservableObject {
    /// Identificadores de las luces tal y como las conoce el servidor.
    static let lightIDs = ["bombilla", "tira"]
    /// Iconos entre los que se puede elegir para cada luz.
    static let iconChoices = ["lightbulb.fill", "wand.and.rays", "sparkles",
                              "moon.stars.fill", "sun.max.fill", "flame.fill"]

    private static let languageKey = "language"
    private static let appearanceKey = "appearance"
    private static let serverURLKey = "serverURL"
    private static let serverTokenKey = "serverToken"
    private static let lightNamesKey = "lightNames"
    private static let lightIconsKey = "lightIcons"
    private static let sensitivityKey = "motionSensitivity"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    /// Dirección del servidor, por ejemplo 192.168.1.200:8090
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Self.serverURLKey) }
    }

    /// Clave compartida con el servidor.
    @Published var serverToken: String {
        didSet { UserDefaults.standard.set(serverToken, forKey: Self.serverTokenKey) }
    }

    /// Sensibilidad del detector de movimiento (1...10).
    @Published var motionSensitivity: Int {
        didSet { UserDefaults.standard.set(motionSensitivity, forKey: Self.sensitivityKey) }
    }

    @Published var lightNames: [String: String] {
        didSet { UserDefaults.standard.set(lightNames, forKey: Self.lightNamesKey) }
    }

    @Published var lightIcons: [String: String] {
        didSet { UserDefaults.standard.set(lightIcons, forKey: Self.lightIconsKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .es
        appearance = AppAppearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .dark
        serverURL = defaults.string(forKey: Self.serverURLKey) ?? ""
        serverToken = defaults.string(forKey: Self.serverTokenKey) ?? ""
        let savedSensitivity = defaults.integer(forKey: Self.sensitivityKey)
        motionSensitivity = savedSensitivity == 0 ? 5 : min(10, max(1, savedSensitivity))
        lightNames = (defaults.dictionary(forKey: Self.lightNamesKey) as? [String: String]) ?? [:]
        lightIcons = (defaults.dictionary(forKey: Self.lightIconsKey) as? [String: String]) ?? [:]
    }

    var colorScheme: ColorScheme {
        appearance == .dark ? .dark : .light
    }

    /// Texto traducido al idioma elegido en la app.
    func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    /// Nombre de la luz: el personalizado o, si no hay, el de por defecto.
    func defaultLightName(_ id: String) -> String {
        t(id == "tira" ? "strip" : "bulb")
    }

    func lightName(_ id: String) -> String {
        let custom = (lightNames[id] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? defaultLightName(id) : custom
    }

    func defaultLightIcon(_ id: String) -> String {
        id == "tira" ? "wand.and.rays" : "lightbulb.fill"
    }

    func lightIcon(_ id: String) -> String {
        lightIcons[id] ?? defaultLightIcon(id)
    }
}
