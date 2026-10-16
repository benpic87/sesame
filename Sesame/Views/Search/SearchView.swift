import SwiftData
import SwiftUI

/// Écran 6 — Recherche temps réel par nom, filtres par type,
/// surlignage du terme dans les résultats.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Document.addedAt, order: .reverse) private var documents: [Document]
    @Query(sort: \Category.createdAt) private var categories: [Category]

    enum TypeFilter: String, CaseIterable {
        case all, images, pdf, notes

        var label: LocalizedStringKey {
            switch self {
            case .all: "Tout"
            case .images: "Images"
            case .pdf: "PDF"
            case .notes: "Notes"
            }
        }

        func matches(_ type: DocumentType) -> Bool {
            switch self {
            case .all: true
            case .images: type == .image
            case .pdf: type == .pdf
            case .notes: type == .note
            }
        }
    }

    @State private var query = ""
    @State private var typeFilter: TypeFilter = .all
    @FocusState private var searchFocused: Bool
    @State private var selectedDocument: Document?

    private var results: [Document] {
        documents.filter { document in
            typeFilter.matches(document.type)
                && (query.isEmpty
                    || document.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    searchBar

                    Picker("Type", selection: $typeFilter) {
                        ForEach(TypeFilter.allCases, id: \.self) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !query.isEmpty {
                        Text("^[\(results.count) résultat](inflect: true)")
                            .appFont(13, .semibold, relativeTo: .footnote)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { document in
                                Button {
                                    selectedDocument = document
                                } label: {
                                    SearchResultRow(
                                        document: document,
                                        categories: categories,
                                        highlight: query
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedDocument) { document in
                DocumentDetailView(document: document)
            }
        }
        .onAppear { searchFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textTertiary)
                TextField("Rechercher un document…", text: $query)
                    .appFont(16, .regular, relativeTo: .body)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))

            Button("Annuler") { dismiss() }
                .appFont(16, .regular, relativeTo: .body)
                .foregroundStyle(Theme.accent)
        }
    }
}

/// Ligne de résultat : vignette, titre avec terme surligné, étiquettes.
struct SearchResultRow: View {
    @Environment(VaultStore.self) private var vault
    let document: Document
    let categories: [Category]
    let highlight: String

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedName)
                    .appFont(15, .bold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let badge = document.type.badge {
                        Text(badge)
                            .appFont(10, .bold, relativeTo: .caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(categories.filter { document.tagIDs.contains($0.id) }.prefix(3)) { category in
                        TagChip(category: category)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(12)
        .card()
    }

    /// Surlignage du terme : fond #ececfa, texte #5b5bd6.
    private var highlightedName: AttributedString {
        var attributed = AttributedString(document.name)
        guard !highlight.isEmpty,
              let range = attributed.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive])
        else { return attributed }
        attributed[range].backgroundColor = Theme.accentTint
        attributed[range].foregroundColor = Theme.accent
        return attributed
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = vault.thumbnail(for: document) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if document.type == .note {
            ZStack {
                Theme.accentTint
                Image(systemName: "note.text")
                    .foregroundStyle(Theme.accent)
            }
        } else {
            StripedPlaceholder()
        }
    }
}
