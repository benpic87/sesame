import SwiftData
import SwiftUI

/// Écran 2 — Accueil / Coffre : filtres par catégorie, grille 2 colonnes,
/// bouton flottant « + Ajouter ».
struct HomeView: View {
    @Environment(VaultStore.self) private var vault
    @Environment(StoreService.self) private var store
    @Query(sort: \Document.addedAt, order: .reverse) private var documents: [Document]
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var activeCategoryID: UUID?
    @State private var showAddSheet = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showNewCategory = false
    @State private var showPaywall = false

    private var filteredDocuments: [Document] {
        guard let activeCategoryID else { return documents }
        return documents.filter { $0.tagIDs.contains(activeCategoryID) }
    }

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
                        filterChips
                        documentGrid
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

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: String(localized: "Tout · \(documents.count)"),
                    isActive: activeCategoryID == nil,
                    dotColor: nil
                ) {
                    activeCategoryID = nil
                }

                ForEach(categories) { category in
                    let count = documents.filter { $0.tagIDs.contains(category.id) }.count
                    FilterChip(
                        label: "\(category.name) \(count)",
                        isActive: activeCategoryID == category.id,
                        dotColor: category.colorToken.main
                    ) {
                        activeCategoryID = activeCategoryID == category.id ? nil : category.id
                    }
                }

                // Chip « + » pointillée : créer une catégorie.
                Button {
                    showNewCategory = true
                } label: {
                    Image(systemName: "plus")
                        .appFont(13, .semibold, relativeTo: .footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 34)
                        .background(
                            Capsule().strokeBorder(
                                Theme.dashed,
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                        )
                }
                .accessibilityLabel("Créer une catégorie")
            }
            .padding(.vertical, 2)
        }
    }

    private var documentGrid: some View {
        Group {
            if filteredDocuments.isEmpty {
                EmptyVaultView(hasAnyDocument: !documents.isEmpty)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(filteredDocuments) { document in
                        NavigationLink {
                            DocumentDetailView(document: document)
                        } label: {
                            DocumentCard(document: document, categories: categories)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let dotColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor, !isActive {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                }
                Text(label)
                    .appFont(13, .semibold, relativeTo: .footnote)
            }
            .foregroundStyle(isActive ? .white : Theme.textSecondary)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(
                isActive ? Theme.accent : Theme.surface,
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(isActive ? .clear : Theme.border, lineWidth: 1))
        }
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
