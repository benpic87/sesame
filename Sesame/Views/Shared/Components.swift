import SwiftUI

/// CTA pleine largeur indigo avec ombre (token « ombre CTA »).
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .appFont(16, .bold, relativeTo: .headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
        }
        .modifier(CTAShadow())
    }
}

/// Bouton secondaire blanc bordé.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .appFont(16, .semibold, relativeTo: .headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                    .fill(Theme.surface)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
    }
}

struct CTAShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.accent.opacity(0.25), radius: 12, x: 0, y: 10)
    }
}

/// Chip d'étiquette de catégorie (fond teinté, texte couleur pleine).
struct TagChip: View {
    let category: Category
    var size: CGFloat = 10.5

    var body: some View {
        Text(category.name)
            .appFont(size, .semibold, relativeTo: .caption2)
            .foregroundStyle(category.colorToken.main)
            .padding(.horizontal, size * 0.85)
            .padding(.vertical, size * 0.4)
            .background(category.colorToken.tint, in: Capsule())
            .lineLimit(1)
    }
}

/// Carte blanche standard (radius 18, bordure, ombre légère).
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.surface)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .shadow(color: Theme.textPrimary.opacity(0.04), radius: 1.5, x: 0, y: 1)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// Placeholder de vignette : rayures diagonales (comme la maquette).
struct StripedPlaceholder: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.surfaceSecondary))
            let step: CGFloat = 14
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 6, y: 0))
                path.addLine(to: CGPoint(x: x + 6, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Theme.border))
                x += step
            }
        }
        .accessibilityHidden(true)
    }
}

/// Formatage des tailles de fichiers (« 2,4 Mo »).
enum Format {
    static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .long, time: .omitted)
    }
}
