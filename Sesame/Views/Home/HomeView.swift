import SwiftData
import SwiftUI

/// Écran 2 — Accueil / Coffre : tuiles de catégories (chacune ouvre ses
/// documents), tuile « Tous les documents », bouton flottant « + Ajouter ».
struct HomeView: View {
    @Environment(VaultStore.self) private var vault
    @Environment(StoreService.self) private var store
    @Query(sort: \Document.addedAt, order: .reverse) private var documents: [Document]
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var showAddSheet = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showNewCategory = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if !store.isPremium {
                            freeBanner
                        }
                        categoryTiles
                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                addButton
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) { AddDocumentSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showNewCategory) { CategoryEditorSheet(category: nil) }
            .fullScreenCover(isPresented: $showSearch) { SearchView() }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var header: some View {
        HStack {
            Text("Coffre")
                .appFont(30, .heavy, relativeTo: .largeTitle, tracking: -0.03)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            RoundIconButton(systemImage: "magnifyingglass", label: "Rechercher") {
                showSearch = true
            }
            RoundIconButton(systemImage: "gearshape.fill", label: "Réglages") {
                showSettings = true
            }
        }
    }

    private var categoryTiles: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(categories) { category in
                    NavigationLink {
                        CategoryDocumentsView(category: category)
                    } label: {
                        CategoryTile(
                            name: category.name,
                            count: documents.filter { $0.tagIDs.contains(category.id) }.count,
                            token: category.colorToken
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Tuile pointillée : créer une catégorie.
                Button {
                    showNewCategory = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Nouvelle catégorie")
                            .appFont(13, .semibold, relativeTo: .footnote)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: CategoryTile.height)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                            .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Créer une catégorie")
            }

            NavigationLink {
                CategoryDocumentsView(category: nil)
            } label: {
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Tous les documents")
                        .appFont(16, .bold, relativeTo: .headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("^[\(documents.count) document](inflect: true)")
                        .appFont(14, .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .card()
                .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    /// Bandeau version gratuite : compteur 3 documents + accès Premium.
    private var freeBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Version gratuite · \(documents.count)/\(StoreService.freeDocumentLimit) documents")
                    .appFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(verbatim: "Premium")
                    .appFont(13, .bold, relativeTo: .footnote)
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
        }
    }

    private var addButton: some View {
        Button {
            if store.canAddDocument(currentCount: documents.count) {
                showAddSheet = true
            } else {
                showPaywall = true
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
                .appFont(15, .bold, relativeTo: .subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(minHeight: 50)
                .background(Theme.textPrimary, in: Capsule())
        }
        .shadow(color: Theme.textPrimary.opacity(0.25), radius: 12, x: 0, y: 10)
        .padding(.bottom, 12)
    }
}

struct RoundIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.surfaceSecondary, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

/// Tuile de catégorie de l'accueil : fond teinté, nom, nombre de documents.
struct CategoryTile: View {
    static let height: CGFloat = 96

    let name: String
    let count: Int
    let token: CategoryColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Circle()
                .fill(token.main)
                .frame(width: 10, height: 10)
            Spacer(minLength: 8)
            Text(name)
                .appFont(16, .bold, relativeTo: .headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text("^[\(count) document](inflect: true)")
                .appFont(13, .semibold, relativeTo: .footnote)
                .foregroundStyle(token.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .leading)
        .background(token.tint, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EmptyVaultView: View {
    let hasAnyDocument: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text(hasAnyDocument ? "Aucun document dans cette catégorie" : "Votre coffre est vide")
                .appFont(15, .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.textSecondary)
            if !hasAnyDocument {
                Text("Tout est chiffré dès l'ajout · rien ne quitte l'appareil")
                    .appFont(12, .regular, relativeTo: .caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
