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
/// Ajouter une couleur : toujours en fin de liste (le nom brut est en base).
enum CategoryColorToken: String, CaseIterable, Codable {
    case indigo, green, amber, pink, blue, teal, red, orange, purple, olive, brown, slate

    /// Couleur vive : pastilles et cercles.
    var main: Color {
        switch self {
        case .indigo: Color(hex: 0x5B5BD6)
        case .green: Color(hex: 0x1E8F6E)
        case .amber: Color(hex: 0xB3762A)
        case .pink: Color(hex: 0xC15C9A)
        case .blue: Color(hex: 0x2F6FD0)
        case .teal: Color(hex: 0x0F7F8C)
        case .red: Color(hex: 0xC23B33)
        case .orange: Color(hex: 0xB5561A)
        case .purple: Color(hex: 0x8549C4)
        case .olive: Color(hex: 0x66711C)
        case .brown: Color(hex: 0x8A5A3C)
        case .slate: Color(hex: 0x56607A)
        }
    }

    /// Fond teinté des tuiles et des étiquettes.
    var tint: Color {
        switch self {
        case .indigo: Color(hex: 0xECECFA)
        case .green: Color(hex: 0xE2F4ED)
        case .amber: Color(hex: 0xFAF0DF)
        case .pink: Color(hex: 0xF9E9F3)
        case .blue: Color(hex: 0xE3EDFB)
        case .teal: Color(hex: 0xDDF2F4)
        case .red: Color(hex: 0xFBE7E5)
        case .orange: Color(hex: 0xFCEBDD)
        case .purple: Color(hex: 0xF1E8FB)
        case .olive: Color(hex: 0xEEF1DA)
        case .brown: Color(hex: 0xF3E9E2)
        case .slate: Color(hex: 0xE9ECF1)
        }
    }

    /// Texte coloré : version assez foncée pour un contraste ≥ 4,5:1 (WCAG AA)
    /// sur `tint` comme sur blanc, et pour du texte blanc posé dessus.
    var ink: Color {
        switch self {
        case .indigo: Color(hex: 0x5858CF)
        case .green: Color(hex: 0x18765B)
        case .amber: Color(hex: 0x905F22)
        case .pink: Color(hex: 0x9C4A7C)
        case .blue: Color(hex: 0x2A65BD)
        case .teal: Color(hex: 0x0D727D)
        case .red: Color(hex: 0xB83830)
        case .orange: Color(hex: 0xA64F17)
        case .purple: Color(hex: 0x8348C2)
        case .olive: Color(hex: 0x636E1B)
        case .brown: Color(hex: 0x8A5A3C)
        case .slate: Color(hex: 0x56607A)
        }
    }

    var localizedName: LocalizedStringKey {
        switch self {
        case .indigo: "Indigo"
        case .green: "Vert"
        case .amber: "Ambre"
        case .pink: "Rose"
        case .blue: "Bleu"
        case .teal: "Turquoise"
        case .red: "Rouge"
        case .orange: "Orange"
        case .purple: "Violet"
        case .olive: "Olive"
        case .brown: "Brun"
        case .slate: "Ardoise"
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
