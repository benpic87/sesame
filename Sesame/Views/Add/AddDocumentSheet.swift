import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Écran 4 — Ajouter un document : 5 méthodes, tout chiffré dès l'ajout.
struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault

    @State private var showScanner = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var showNoteEditor = false
    @State private var galleryItem: PhotosPickerItem?

    /// Données acquises en attente de nommage/étiquetage.
    @State private var pendingImport: PendingImport?
    /// Identifiant de l'asset galerie, pour proposer la suppression de l'original.
    @State private var galleryAssetIdentifier: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Sans caméra (simulateur), les cartes restent visibles mais
                        // désactivées : VNDocumentCameraViewController lève une
                        // exception à l'init sur un appareil non compatible.
                        AddMethodCard(
                            icon: "doc.viewfinder",
                            title: "Scanner un document",
                            subtitle: DocumentScannerView.isSupported
                                ? "Recadrage automatique des bords"
                                : "Nécessite l'appareil photo d'un iPhone",
                            isPrimary: true,
                            isEnabled: DocumentScannerView.isSupported
                        ) { showScanner = true }

                        AddMethodCard(
                            icon: "camera",
                            title: "Prendre une photo",
                            subtitle: CameraPicker.isAvailable
                                ? "Appareil photo, jamais enregistrée ailleurs"
                                : "Nécessite l'appareil photo d'un iPhone",
                            isEnabled: CameraPicker.isAvailable
                        ) { showCamera = true }

                        PhotosPicker(
                            selection: $galleryItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            AddMethodCardLabel(
                                icon: "photo.on.rectangle",
                                title: "Importer de la galerie",
                                subtitle: "L'original peut être supprimé après import",
                                isPrimary: false
                            )
                        }

                        AddMethodCard(
                            icon: "doc",
                            title: "Importer un fichier",
                            subtitle: "PDF, images, depuis Fichiers"
                        ) { showFileImporter = true }

                        AddMethodCard(
                            icon: "note.text",
                            title: "Nouvelle note",
                            subtitle: "Texte chiffré : codes, numéros, mémos"
                        ) { showNoteEditor = true }

                        Text("Tout est chiffré dès l'ajout · rien ne quitte l'appareil")
                            .appFont(12, .regular, relativeTo: .caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ajouter un document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { result in
                if case let .success(scan) = result {
                    pendingImport = scan
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { imageData in
                pendingImport = PendingImport(
                    data: imageData,
                    type: .image,
                    fileExtension: "jpg",
                    suggestedName: String(localized: "Photo du \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                )
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView(document: nil) {
                dismiss()
            }
        }
        .sheet(item: $pendingImport) { pending in
            ImportFormView(pending: pending, galleryAssetIdentifier: galleryAssetIdentifier) {
                galleryAssetIdentifier = nil
                dismiss()
            }
        }
        .onChange(of: galleryItem) { _, item in
            guard let item else { return }
            galleryAssetIdentifier = item.itemIdentifier
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    pendingImport = PendingImport(
                        data: data,
                        type: .image,
                        fileExtension: "jpg",
                        suggestedName: String(localized: "Image importée")
                    )
                }
                galleryItem = nil
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        pendingImport = PendingImport(
            data: data,
            type: ext == "pdf" ? .pdf : .image,
            fileExtension: ext.isEmpty ? "bin" : ext,
            suggestedName: url.deletingPathExtension().lastPathComponent
        )
    }
}

/// Données acquises, en attente du formulaire nom + étiquettes.
struct PendingImport: Identifiable {
    let id = UUID()
    let data: Data
    let type: DocumentType
    let fileExtension: String
    let suggestedName: String
}

// MARK: Cartes de méthode

private struct AddMethodCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var isPrimary = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AddMethodCardLabel(icon: icon, title: title, subtitle: subtitle, isPrimary: isPrimary)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct AddMethodCardLabel: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isPrimary ? Theme.accent : Theme.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    isPrimary ? Color.white : Theme.surfaceSecondary,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(16, .bold, relativeTo: .headline)
                    .foregroundStyle(isPrimary ? .white : Theme.textPrimary)
                Text(subtitle)
                    .appFont(13, .regular, relativeTo: .footnote)
                    .foregroundStyle(isPrimary ? .white.opacity(0.85) : Theme.textSecondary)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(isPrimary ? Theme.accent : Theme.surface)
                .strokeBorder(isPrimary ? .clear : Theme.border, lineWidth: 1)
        )
        .shadow(
            color: isPrimary ? Theme.accent.opacity(0.25) : Theme.textPrimary.opacity(0.04),
            radius: isPrimary ? 12 : 1.5, x: 0, y: isPrimary ? 10 : 1
        )
    }
}
