import PDFKit
import SwiftData
import SwiftUI

/// Écran 3 — Détail document : aperçu, étiquettes éditables, métadonnées,
/// alerte d'expiration, partage sécurisé.
struct DocumentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @Bindable var document: Document

    @State private var showShareSheet = false
    @State private var showNoteEditor = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var confirmDelete = false
    /// Contenu déchiffré une seule fois au chargement, jamais à chaque rendu.
    @State private var previewData: Data?
    @State private var showViewer = false

    /// Images et PDF s'ouvrent en plein écran ; les notes sont déjà lisibles.
    private var canOpenViewer: Bool {
        document.type != .note && previewData != nil
    }

    private var documentCategories: [Category] {
        categories.filter { document.tagIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if canOpenViewer {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(.black.opacity(0.5), in: Circle())
                                    .padding(10)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if canOpenViewer { showViewer = true }
                        }
                        .accessibilityAddTraits(canOpenViewer ? .isButton : [])
                        .accessibilityLabel(canOpenViewer ? Text("Afficher en plein écran") : Text(document.name))

                    Text(document.name)
                        .appFont(24, .heavy, relativeTo: .title2, tracking: -0.02)
                        .foregroundStyle(Theme.textPrimary)

                    tagRow

                    metaCard

                    // Un seul bouton : le choix chiffré / original se fait ensuite.
                    PrimaryButton(title: "Partager", systemImage: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    .padding(.top, 8)

                    Button("Supprimer du coffre", role: .destructive) {
                        confirmDelete = true
                    }
                    .appFont(15, .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.alert)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        // Recharge aussi après édition d'une note (fermeture de l'éditeur).
        .task(id: showNoteEditor) {
            previewData = try? vault.decryptedData(for: document)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text("Coffre")
                    }
                    .appFont(16, .semibold, relativeTo: .body)
                    .foregroundStyle(Theme.accent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier") {
                    if document.type == .note {
                        showNoteEditor = true
                    } else {
                        renameText = document.name
                        showRename = true
                    }
                }
                .appFont(16, .semibold, relativeTo: .body)
                .foregroundStyle(Theme.accent)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            SecureShareSheet(document: document)
        }
        .fullScreenCover(isPresented: $showViewer) {
            if let previewData {
                DocumentViewer(type: document.type, data: previewData)
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView(document: document)
        }
        .alert("Renommer le document", isPresented: $showRename) {
            TextField("Nom", text: $renameText)
            Button("Renommer") {
                if !renameText.isEmpty {
                    document.name = renameText
                    vault.save()
                }
            }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Supprimer ce document ?", isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) {
                vault.delete(document)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le fichier chiffré sera définitivement effacé de l'appareil.")
        }
    }

    // MARK: Aperçu

    @ViewBuilder
    private var preview: some View {
        switch document.type {
        case .image:
            if let data = previewData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                StripedPlaceholder()
            }
        case .pdf:
            if let data = previewData {
                // Aperçu figé : le toucher ouvre le visualiseur plein écran.
                PDFPreview(data: data)
                    .allowsHitTesting(false)
            } else {
                StripedPlaceholder()
            }
        case .note:
            ScrollView {
                Text(String(decoding: previewData ?? Data(), as: UTF8.self))
                    .appFont(15, .regular, relativeTo: .body)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Theme.surface)
        }
    }

    // MARK: Étiquettes

    private var tagRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(documentCategories) { category in
                Menu {
                    Button("Retirer l'étiquette", role: .destructive) {
                        document.tagIDs.removeAll { $0 == category.id }
                        vault.save()
                    }
                } label: {
                    TagChip(category: category, size: 12)
                }
            }

            Menu {
                ForEach(categories.filter { !document.tagIDs.contains($0.id) }) { category in
                    Button(category.name) {
                        document.tagIDs.append(category.id)
                        vault.save()
                    }
                }
            } label: {
                Text("+ étiquette")
                    .appFont(12, .semibold, relativeTo: .caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().strokeBorder(
                            Theme.dashed,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                    )
            }
        }
    }

    // MARK: Métadonnées

    private var metaCard: some View {
        VStack(spacing: 0) {
            MetaRow(label: "Ajouté le", value: Format.date(document.addedAt))
            if let expiresAt = document.expiresAt {
                Divider().overlay(Theme.border)
                MetaRow(
                    label: "Expire le",
                    value: Format.date(expiresAt),
                    isAlert: document.isExpiringSoon()
                )
            }
            Divider().overlay(Theme.border)
            MetaRow(
                label: "Taille",
                value: "\(Format.fileSize(document.sizeBytes)) · \(document.originalExtension.uppercased())"
            )
        }
        .card()
    }
}

private struct MetaRow: View {
    let label: LocalizedStringKey
    let value: String
    var isAlert = false

    var body: some View {
        HStack {
            Text(label)
                .appFont(14.5, .regular, relativeTo: .subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .appFont(14.5, isAlert ? .bold : .semibold, relativeTo: .subheadline)
                .foregroundStyle(isAlert ? Theme.alert : Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Aperçu PDF (données déchiffrées, jamais écrites sur disque).
struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .white
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
