import SwiftUI
import UIKit

/// Sistema de diseño del panel.
///
/// Idea: un instrumento de pared que se lee de un vistazo y de noche no deslumbra.
///  - Lo que se LEE (hora, tiempo) es tipografía plana sobre el fondo, sin tarjetas.
///  - Lo que se TOCA (luces, candado) es un objeto con volumen y brilla con el color real de la luz.
///  - El rojo existe solo para la alarma; el ámbar es la luz cálida y el único acento.
enum Theme {
    static let background = dynamic(dark: 0x101318, light: 0xE9ECF0)
    static let surface    = dynamic(dark: 0x181C23, light: 0xF6F7F9)
    static let raised     = dynamic(dark: 0x212733, light: 0xFFFFFF)
    static let hairline   = dynamic(dark: 0x2B3340, light: 0xCDD3DB)
    static let text       = dynamic(dark: 0xECE7DC, light: 0x14181D)
    static let textMuted  = dynamic(dark: 0x8C95A3, light: 0x5D6773)
    static let lamp       = dynamic(dark: 0xF2B04C, light: 0xB8741A)   // acento: luz cálida
    static let signal     = dynamic(dark: 0xE5484D, light: 0xC9302F)   // solo alarma
    static let ok         = dynamic(dark: 0x5BC08A, light: 0x2E8F5E)
    /// Color del texto sobre algo iluminado (siempre oscuro).
    static let ink        = Color(UIColor(hex: 0x14181D))

    /// Radios: el tamaño del objeto decide la curvatura.
    static let radiusLarge: CGFloat = 20     // cámara, losetas de luz
    static let radiusMedium: CGFloat = 14
    static let radiusSmall: CGFloat = 10

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    /// Configura la barra de navegación y las listas de UIKit para que casen con el diseño.
    static func applyAppearance() {
        let background = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x101318) : UIColor(hex: 0xE9ECF0)
        }
        let text = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0xECE7DC) : UIColor(hex: 0x14181D)
        }
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = background
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.foregroundColor: text]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UITableView.appearance().backgroundColor = background
        let surface = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x181C23) : UIColor(hex: 0xF6F7F9)
        }
        let line = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x2B3340) : UIColor(hex: 0xCDD3DB)
        }
        UITableViewCell.appearance().backgroundColor = surface
        UITableView.appearance().separatorColor = line
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Font {
    /// Cifras con serifa (hora, temperaturas): carácter propio y buena lectura a distancia.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Texto de interfaz.
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Superficie táctil: fondo con volumen suave y borde fino.
struct RaisedSurface: ViewModifier {
    var radius: CGFloat = Theme.radiusLarge

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func raisedSurface(radius: CGFloat = Theme.radiusLarge) -> some View {
        modifier(RaisedSurface(radius: radius))
    }
}
