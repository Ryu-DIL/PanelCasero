import CryptoKit
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
    private static let lightChangeKey = "lightChangeIsMotion"
    private static let pinHashKey = "alarmPINHash"
    private static let pinSaltKey = "alarmPINSalt"
    private static let pinLengthKey = "alarmPINLength"
    private static let sirenKey = "sirenSeconds"
    private static let weatherCityKey = "weatherCity"
    private static let orientationKey = "orientationMode"
    private static let idleDimKey = "idleDim"
    private static let autoBrightnessKey = "autoBrightness"
    private static let motionBrightnessKey = "motionBrightness"
    private static let idleSecondsKey = "idleSeconds"
    private static let touchSecondsKey = "touchSeconds"

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

    /// Si es true, un cambio brusco de luz en la habitación cuenta como movimiento.
    @Published var lightChangeIsMotion: Bool {
        didSet { UserDefaults.standard.set(lightChangeIsMotion, forKey: Self.lightChangeKey) }
    }

    /// El PIN no se guarda: solo una huella (hash) con sal.
    @Published private(set) var alarmPINHash: String {
        didSet { UserDefaults.standard.set(alarmPINHash, forKey: Self.pinHashKey) }
    }

    @Published private(set) var alarmPINSalt: String {
        didSet { UserDefaults.standard.set(alarmPINSalt, forKey: Self.pinSaltKey) }
    }

    @Published private(set) var alarmPINLength: Int {
        didSet { UserDefaults.standard.set(alarmPINLength, forKey: Self.pinLengthKey) }
    }

    /// Segundos que suena la sirena tras una alerta (0 = apagada).
    @Published var sirenSeconds: Int {
        didSet { UserDefaults.standard.set(sirenSeconds, forKey: Self.sirenKey) }
    }

    /// Orientación fija de la pantalla (un panel de pared siempre está colgado igual).
    @Published var orientationMode: OrientationMode {
        didSet { UserDefaults.standard.set(orientationMode.rawValue, forKey: Self.orientationKey) }
    }

    /// Oscurecimiento extra cuando la pantalla está en reposo (0...0.8).
    @Published var idleDim: Double {
        didSet { UserDefaults.standard.set(idleDim, forKey: Self.idleDimKey) }
    }

    /// Si es false, la app no toca el brillo de la pantalla.
    @Published var autoBrightness: Bool {
        didSet { UserDefaults.standard.set(autoBrightness, forKey: Self.autoBrightnessKey) }
    }

    /// Brillo (0.1...1) cuando hay movimiento.
    @Published var motionBrightness: Double {
        didSet { UserDefaults.standard.set(motionBrightness, forKey: Self.motionBrightnessKey) }
    }

    /// Segundos sin movimiento para pasar a reposo.
    @Published var idleSeconds: Double {
        didSet { UserDefaults.standard.set(idleSeconds, forKey: Self.idleSecondsKey) }
    }

    /// Segundos que se mantiene el brillo máximo tras tocar.
    @Published var touchSeconds: Double {
        didSet { UserDefaults.standard.set(touchSeconds, forKey: Self.touchSecondsKey) }
    }

    /// Cambia cuando cualquier ajuste de brillo cambia (para reaplicarlos).
    var brightnessSignature: [Double] {
        [autoBrightness ? 1 : 0, motionBrightness, idleSeconds, touchSeconds, idleDim]
    }

    /// Ciudad de la previsión del tiempo.
    @Published var weatherCity: String {
        didSet { UserDefaults.standard.set(weatherCity, forKey: Self.weatherCityKey) }
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
        lightChangeIsMotion = defaults.bool(forKey: Self.lightChangeKey)
        orientationMode = OrientationMode(rawValue: defaults.string(forKey: Self.orientationKey) ?? "") ?? .landscape
        idleDim = defaults.object(forKey: Self.idleDimKey) == nil ? 0.4 : min(0.8, max(0, defaults.double(forKey: Self.idleDimKey)))
        autoBrightness = defaults.object(forKey: Self.autoBrightnessKey) == nil ? true : defaults.bool(forKey: Self.autoBrightnessKey)
        motionBrightness = defaults.object(forKey: Self.motionBrightnessKey) == nil ? 0.4 : min(1, max(0.1, defaults.double(forKey: Self.motionBrightnessKey)))
        idleSeconds = defaults.object(forKey: Self.idleSecondsKey) == nil ? 60 : min(300, max(15, defaults.double(forKey: Self.idleSecondsKey)))
        touchSeconds = defaults.object(forKey: Self.touchSecondsKey) == nil ? 20 : min(60, max(5, defaults.double(forKey: Self.touchSecondsKey)))
        weatherCity = defaults.string(forKey: Self.weatherCityKey) ?? "Mislata"
        alarmPINHash = defaults.string(forKey: Self.pinHashKey) ?? ""
        alarmPINSalt = defaults.string(forKey: Self.pinSaltKey) ?? ""
        let savedLength = defaults.integer(forKey: Self.pinLengthKey)
        alarmPINLength = savedLength == 0 ? 4 : min(8, max(4, savedLength))
        sirenSeconds = defaults.object(forKey: Self.sirenKey) == nil ? 30 : defaults.integer(forKey: Self.sirenKey)
        lightNames = (defaults.dictionary(forKey: Self.lightNamesKey) as? [String: String]) ?? [:]
        lightIcons = (defaults.dictionary(forKey: Self.lightIconsKey) as? [String: String]) ?? [:]
    }

    // MARK: - PIN de la alarma y de los ajustes

    var hasPIN: Bool { !alarmPINHash.isEmpty }

    func setPIN(_ pin: String) {
        let salt = UUID().uuidString
        alarmPINSalt = salt
        alarmPINHash = Self.hash(pin, salt: salt)
        alarmPINLength = pin.count
    }

    func verifyPIN(_ pin: String) -> Bool {
        guard hasPIN else { return false }
        return Self.hash(pin, salt: alarmPINSalt) == alarmPINHash
    }

    private static func hash(_ pin: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + pin).utf8)).map { String(format: "%02x", $0) }.joined()
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
