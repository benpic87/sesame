import SwiftUI

/// Design tokens « Pop clair » (voir design_handoff_sesame/README.md).
enum Theme {
    // MARK: Couleurs
    static let background = Color(hex: 0xFBFBFD)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceSecondary = Color(hex: 0xF0F0F4)
    static let border = Color(hex: 0xECECF1)
    static let dashed = Color(hex: 0xD5D5DE)

    static let textPrimary = Color(hex: 0x17171F)
    static let textSecondary = Color(hex: 0x71717D)
    static let textTertiary = Color(hex: 0xA5A5B0)

    static let accent = Color(hex: 0x5B5BD6)
    static let accentTint = Color(hex: 0xECECFA)

    /// Couleur destructive / alerte d'expiration.
    static let alert = Color(hex: 0xC15C9A)
    static let alertTint = Color(hex: 0xF9E9F3)

    // MARK: Rayons
    static let radiusCard: CGFloat = 18
    static let radiusButton: CGFloat = 16
    static let radiusField: CGFloat = 14
    static let radiusSheet: CGFloat = 28

}

/// Jetons de couleur des catégories (nom stocké en base, couleurs résolues ici).
enum CategoryColorToken: String, CaseIterable, Codable {
    case indigo, green, amber, pink

    var main: Color {
        switch self {
        case .indigo: Color(hex: 0x5B5BD6)
        case .green: Color(hex: 0x1E8F6E)
        case .amber: Color(hex: 0xB3762A)
        case .pink: Color(hex: 0xC15C9A)
        }
    }

    var tint: Color {
        switch self {
        case .indigo: Color(hex: 0xECECFA)
        case .green: Color(hex: 0xE2F4ED)
        case .amber: Color(hex: 0xFAF0DF)
        case .pink: Color(hex: 0xF9E9F3)
        }
    }

    var localizedName: LocalizedStringKey {
        switch self {
        case .indigo: "Indigo"
        case .green: "Vert"
        case .amber: "Ambre"
        case .pink: "Rose"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Police système à taille fixe de maquette, mise à l'échelle par Dynamic Type.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let tracking: CGFloat

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle, tracking: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.tracking = tracking
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .tracking(tracking * size)
    }
}

extension View {
    /// `tracking` en em (ex. -0.03 pour les grands titres).
    func appFont(
        _ size: CGFloat,
        _ weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body,
        tracking: CGFloat = 0
    ) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, relativeTo: style, tracking: tracking))
    }
}
