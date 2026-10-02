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
        "power":         ["es": "Encendida", "ca": "Encesa", "en": "Power", "de": "Ein/Aus"],
        "color":         ["es": "Color", "ca": "Color", "en": "Color", "de": "Farbe"],
        "white":         ["es": "Blanco", "ca": "Blanc", "en": "White", "de": "Weiß"],
        "brightness":    ["es": "Brillo", "ca": "Brillantor", "en": "Brightness", "de": "Helligkeit"],
        "temperature":   ["es": "Temperatura del blanco", "ca": "Temperatura del blanc", "en": "White temperature", "de": "Weißtemperatur"],
        "warm":          ["es": "Cálido", "ca": "Càlid", "en": "Warm", "de": "Warm"],
        "cool":          ["es": "Frío", "ca": "Fred", "en": "Cool", "de": "Kalt"],
        "favorites":     ["es": "Favoritos", "ca": "Preferits", "en": "Favorites", "de": "Favoriten"],
        "delete_favorite": ["es": "¿Borrar este favorito?", "ca": "Vols esborrar este preferit?", "en": "Delete this favorite?", "de": "Diesen Favoriten löschen?"],
        "delete":        ["es": "Borrar", "ca": "Esborrar", "en": "Delete", "de": "Löschen"],
        "cancel":        ["es": "Cancelar", "ca": "Cancel·lar", "en": "Cancel", "de": "Abbrechen"],
        "server":        ["es": "Servidor", "ca": "Servidor", "en": "Server", "de": "Server"],
        "token":         ["es": "Clave (token)", "ca": "Clau (token)", "en": "Key (token)", "de": "Schlüssel (Token)"],
        "test_connection": ["es": "Probar conexión", "ca": "Provar la connexió", "en": "Test connection", "de": "Verbindung testen"],
        "connection_ok": ["es": "Conexión correcta", "ca": "Connexió correcta", "en": "Connection OK", "de": "Verbindung OK"],
        "connection_error": ["es": "No se pudo conectar con el servidor", "ca": "No s'ha pogut connectar amb el servidor", "en": "Could not reach the server", "de": "Server nicht erreichbar"],
        "unauthorized":  ["es": "Clave incorrecta", "ca": "Clau incorrecta", "en": "Wrong key", "de": "Falscher Schlüssel"],
        "not_configured": ["es": "Falta la dirección o la clave", "ca": "Falta l'adreça o la clau", "en": "Address or key missing", "de": "Adresse oder Schlüssel fehlt"],
        "offline":       ["es": "Sin conexión", "ca": "Sense connexió", "en": "Offline", "de": "Offline"],
        "no_server":     ["es": "Sin servidor", "ca": "Sense servidor", "en": "No server", "de": "Kein Server"],
        "name":          ["es": "Nombre", "ca": "Nom", "en": "Name", "de": "Name"],
        "icon":          ["es": "Icono", "ca": "Icona", "en": "Icon", "de": "Symbol"],
        "coming_soon":   ["es": "Próximamente", "ca": "Pròximament", "en": "Coming soon", "de": "Demnächst"]
    ]
}
