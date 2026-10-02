import SwiftUI

struct FavoriteColor: Codable, Identifiable, Equatable {
    var id = UUID()
    var hue: Double
    var saturation: Double
    var brightness: Double
}

/// Colores favoritos de acceso rápido (se guardan en el iPhone).
final class FavoritesStore: ObservableObject {
    static let maxItems = 8
    private static let key = "favoriteColors"

    @Published private(set) var items: [FavoriteColor] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let list = try? JSONDecoder().decode([FavoriteColor].self, from: data) {
            items = list
        } else {
            // Favoritos de partida: morado, verde y cian.
            items = [
                FavoriteColor(hue: 270, saturation: 90, brightness: 100),
                FavoriteColor(hue: 120, saturation: 100, brightness: 100),
                FavoriteColor(hue: 180, saturation: 100, brightness: 100)
            ]
        }
    }

    func add(hue: Double, saturation: Double, brightness: Double) {
        guard items.count < Self.maxItems else { return }
        items.append(FavoriteColor(hue: hue, saturation: saturation, brightness: brightness))
    }

    func remove(_ favorite: FavoriteColor) {
        items.removeAll { $0.id == favorite.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
