import Foundation

/// Traducciones de la app. El idioma se cambia desde Ajustes sin reiniciar.
enum L10n {
    static func string(_ key: String, language: AppLanguage) -> String {
        guard let entry = table[key] else { return key }
        return entry[language.rawValue] ?? entry["es"] ?? key
    }

    private static let table: [String: [String: String]] = [
        "lights":        ["es": "Luces", "ca": "Llums", "en": "Lights", "de": "Lichter"],
        "camera":        ["es": "Cámara", "ca": "Càmera", "en": "Camera", "de": "Kamera"],
        "weather":       ["es": "Tiempo", "ca": "Temps", "en": "Weather", "de": "Wetter"],
        "settings":      ["es": "Ajustes", "ca": "Configuració", "en": "Settings", "de": "Einstellungen"],
        "appearance":    ["es": "Apariencia", "ca": "Aparença", "en": "Appearance", "de": "Erscheinungsbild"],
        "dark":          ["es": "Oscuro", "ca": "Fosc", "en": "Dark", "de": "Dunkel"],
        "light":         ["es": "Claro", "ca": "Clar", "en": "Light", "de": "Hell"],
        "language":      ["es": "Idioma", "ca": "Idioma", "en": "Language", "de": "Sprache"],
        "close":         ["es": "Cerrar", "ca": "Tancar", "en": "Close", "de": "Schließen"],
        "bulb":          ["es": "Bombilla", "ca": "Bombeta", "en": "Bulb", "de": "Glühbirne"],
        "strip":         ["es": "Tira LED", "ca": "Tira LED", "en": "LED strip", "de": "LED-Streifen"],
        "on":            ["es": "Encendida", "ca": "Encesa", "en": "On", "de": "An"],
        "off":           ["es": "Apagada", "ca": "Apagada", "en": "Off", "de": "Aus"],
        "color_bright":  ["es": "Color y brillo", "ca": "Color i brillantor", "en": "Color and brightness", "de": "Farbe und Helligkeit"],
        "test_section":  ["es": "Pruebas (se quitará)", "ca": "Proves (s'eliminarà)", "en": "Tests (will be removed)", "de": "Tests (wird entfernt)"],
        "simulate_motion": ["es": "Simular movimiento", "ca": "Simular moviment", "en": "Simulate motion", "de": "Bewegung simulieren"],
        "coming_soon":   ["es": "Próximamente", "ca": "Pròximament", "en": "Coming soon", "de": "Demnächst"]
    ]
}
