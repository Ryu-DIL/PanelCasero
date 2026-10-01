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
    private static let languageKey = "language"
    private static let appearanceKey = "appearance"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey) }
    }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        language = AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .es
        appearance = AppAppearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .dark
    }

    var colorScheme: ColorScheme {
        appearance == .dark ? .dark : .light
    }

    /// Texto traducido al idioma elegido en la app.
    func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }
}
