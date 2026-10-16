import SwiftUI

/// Carte de document de la grille : vignette 110 pt, badge type, titre, étiquettes.
struct DocumentCard: View {
    @Environment(VaultStore.self) private var vault
    let document: Document
    let categories: [Category]

    private var documentCategories: [Category] {
        categories.filter { document.tagIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                // clipShape ne masque que l'affichage : une photo en portrait
                // (scaledToFill) déborde sinon en zone touchable invisible,
                // jusque sur les catégories au-dessus de la grille.
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if let badge = document.type.badge {
                        Text(badge)
                            .appFont(10, .bold, relativeTo: .caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }

            Text(document.name)
                .appFont(14, .bold, relativeTo: .subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !documentCategories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(documentCategories.prefix(2)) { category in
                        TagChip(category: category)
                    }
                    if documentCategories.count > 2 {
                        Text("+\(documentCategories.count - 2)")
                            .appFont(10.5, .semibold, relativeTo: .caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = vault.thumbnail(for: document) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if document.type == .note {
            ZStack {
                Theme.accentTint
                Image(systemName: "note.text")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
            }
        } else {
            StripedPlaceholder()
        }
    }
}
