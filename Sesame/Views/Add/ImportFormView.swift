import Photos
import SwiftData
import SwiftUI

/// Dernière étape d'un import : nom, expiration éventuelle, étiquettes.
/// Après un import galerie, propose la suppression de l'original.
struct ImportFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @Query(sort: \Category.createdAt) private var categories: [Category]

    let pending: PendingImport
    let galleryAssetIdentifier: String?
    let onDone: () -> Void

    @State private var name: String
    @State private var hasExpiration = false
    @State private var expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var askDeleteOriginal = false
    @State private var importError = false

    init(pending: PendingImport, galleryAssetIdentifier: String?, onDone: @escaping () -> Void) {
        self.pending = pending
        self.galleryAssetIdentifier = galleryAssetIdentifier
        self.onDone = onDone
        _name = State(initialValue: pending.suggestedName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Nom du document", text: $name)
                            .appFont(16, .semibold, relativeTo: .headline)
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Date d'expiration", isOn: $hasExpiration)
                                .appFont(15, .semibold, relativeTo: .subheadline)
                                .tint(Theme.accent)
                            if hasExpiration {
                                DatePicker("Expire le", selection: $expiresAt, displayedComponents: .date)
                                    .appFont(15, .regular, relativeTo: .subheadline)
                            }
                        }
                        .padding(16)
                        .card()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Étiquettes")
                                .appFont(12.5, .semibold, relativeTo: .caption)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.textTertiary)
                            TagSelectionGrid(categories: categories, selection: $selectedTagIDs)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()

                        PrimaryButton(title: "Ajouter au coffre", systemImage: "lock.fill") {
                            importDocument()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nouveau document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .alert("Supprimer l'original de la galerie ?", isPresented: $askDeleteOriginal) {
                Button("Supprimer l'original", role: .destructive) {
                    deleteGalleryOriginal()
                    finish()
                }
                Button("Conserver", role: .cancel) { finish() }
            } message: {
                Text("Le document est maintenant chiffré dans Sésame. L'original en clair peut être retiré de votre galerie.")
            }
            .alert("Impossible d'ajouter le document", isPresented: $importError) {
                Button("OK", role: .cancel) {}
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
    }

    private func importDocument() {
        do {
            try vault.importDocument(
                data: pending.data,
                name: name.isEmpty ? pending.suggestedName : name,
                type: pending.type,
                fileExtension: pending.fileExtension,
                tagIDs: Array(selectedTagIDs),
                expiresAt: hasExpiration ? expiresAt : nil
            )
            if galleryAssetIdentifier != nil {
                askDeleteOriginal = true
            } else {
                finish()
            }
        } catch {
            importError = true
        }
    }

    private func deleteGalleryOriginal() {
        guard let identifier = galleryAssetIdentifier else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard assets.count > 0 else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    private func finish() {
        dismiss()
        onDone()
    }
}

/// Grille de sélection d'étiquettes (multi-sélection, cibles ≥ 44 pt).
struct TagSelectionGrid: View {
    let categories: [Category]
    @Binding var selection: Set<UUID>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(categories) { category in
                let isSelected = selection.contains(category.id)
                Button {
                    if isSelected {
                        selection.remove(category.id)
                    } else {
                        selection.insert(category.id)
                    }
                } label: {
                    HStack(spacing: 5) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(category.name)
                            .appFont(13, .semibold, relativeTo: .footnote)
                    }
                    .foregroundStyle(isSelected ? .white : category.colorToken.main)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(
                        isSelected ? category.colorToken.main : category.colorToken.tint,
                        in: Capsule()
                    )
                }
            }
        }
    }
}

/// Disposition en lignes qui replie les chips (équivalent flex-wrap).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let extra = current.indices.isEmpty ? size.width : size.width + spacing
            if current.width + extra > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.indices.append(index)
            current.width += current.indices.count == 1 ? size.width : size.width + spacing
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
