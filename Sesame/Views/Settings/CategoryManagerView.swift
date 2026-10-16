import SwiftData
import SwiftUI

/// Gestion des catégories : créer, renommer, changer la couleur, supprimer.
struct CategoryManagerView: View {
    @Environment(VaultStore.self) private var vault
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query private var documents: [Document]

    @State private var editingCategory: Category?
    @State private var showNewCategory = false
    @State private var categoryToDelete: Category?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(categories) { category in
                        let count = documents.filter { $0.tagIDs.contains(category.id) }.count
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(category.colorToken.main)
                                    .frame(width: 14, height: 14)
                                Text(category.name)
                                    .appFont(15.5, .semibold, relativeTo: .subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("^[\(count) document](inflect: true)")
                                    .appFont(13, .regular, relativeTo: .footnote)
                                    .foregroundStyle(Theme.textTertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(16)
                            .card()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Supprimer", role: .destructive) {
                                categoryToDelete = category
                            }
                        }
                    }

                    Button {
                        showNewCategory = true
                    } label: {
                        Label("Nouvelle catégorie", systemImage: "plus")
                            .appFont(15, .semibold, relativeTo: .subheadline)
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                                    .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle("Catégories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(category: category)
        }
        .sheet(isPresented: $showNewCategory) {
            CategoryEditorSheet(category: nil)
        }
        .alert(
            "Supprimer cette catégorie ?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            )
        ) {
            Button("Supprimer", role: .destructive) {
                if let category = categoryToDelete {
                    vault.deleteCategory(category)
                }
                categoryToDelete = nil
            }
            Button("Annuler", role: .cancel) { categoryToDelete = nil }
        } message: {
            Text("L'étiquette sera retirée des documents qui la portent. Les documents ne sont pas supprimés.")
        }
    }
}

/// Création / édition d'une catégorie : nom + couleur parmi la palette des tokens.
struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault

    let category: Category?

    @State private var name = ""
    @State private var colorToken: CategoryColorToken = .indigo

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    TextField("Nom de la catégorie", text: $name)
                        .appFont(16, .semibold, relativeTo: .headline)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Couleur")
                            .appFont(12.5, .semibold, relativeTo: .caption)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.textTertiary)

                        // 12 couleurs : grille de 6 par ligne.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                            ForEach(CategoryColorToken.allCases, id: \.self) { token in
                                Button {
                                    colorToken = token
                                } label: {
                                    Circle()
                                        .fill(token.main)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if colorToken == token {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .accessibilityLabel(Text(token.localizedName))
                            }
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(category == nil ? "Nouvelle catégorie" : "Modifier la catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(category == nil ? "Créer" : "Enregistrer") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(Theme.radiusSheet)
        .onAppear {
            if let category {
                name = category.name
                colorToken = category.colorToken
            }
        }
    }

    private func save() {
        if let category {
            category.name = name
            category.colorTokenRaw = colorToken.rawValue
            vault.save()
        } else {
            vault.createCategory(name: name, colorToken: colorToken)
        }
        dismiss()
    }
}
