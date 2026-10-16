import SwiftData
import SwiftUI

/// Documents d'une catégorie (ou de tout le coffre si `category` est nil),
/// ouverts depuis une tuile de l'accueil.
struct CategoryDocumentsView: View {
    @Query(sort: \Document.addedAt, order: .reverse) private var documents: [Document]
    @Query(sort: \Category.createdAt) private var categories: [Category]

    let category: Category?

    private var filteredDocuments: [Document] {
        guard let category else { return documents }
        return documents.filter { $0.tagIDs.contains(category.id) }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                if filteredDocuments.isEmpty {
                    EmptyVaultView(hasAnyDocument: !documents.isEmpty)
                        .padding(.top, 80)
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
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(category.map { Text($0.name) } ?? Text("Tous les documents"))
        .navigationBarTitleDisplayMode(.large)
        // L'accueil masque sa barre : on la réaffiche pour le titre et le retour.
        .toolbar(.visible, for: .navigationBar)
    }
}
