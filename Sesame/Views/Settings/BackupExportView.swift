import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Sauvegarde chiffrée locale : export manuel vers Fichiers, jamais automatique.
/// Le conteneur est protégé par une phrase de passe générée, à noter à part.
struct BackupExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @Query private var documents: [Document]
    @Query private var categories: [Category]

    @State private var passphrase = PassphraseGenerator.generate()
    @State private var copied = false
    @State private var exportDocument: BackupFileDocument?
    @State private var showExporter = false
    @State private var exportError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("La sauvegarde contient tous vos documents et catégories, chiffrés avec la phrase ci-dessous. Notez-la : sans elle, la sauvegarde est illisible.")
                        .appFont(14.5, .regular, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phrase de récupération")
                            .appFont(12.5, .semibold, relativeTo: .caption)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.textTertiary)

                        HStack {
                            Text(passphrase)
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Button(copied ? "Copié ✓" : "Copier") {
                                UIPasteboard.general.setSensitive(passphrase)
                                copied = true
                            }
                            .appFont(14, .bold, relativeTo: .footnote)
                            .foregroundStyle(Theme.accent)
                        }
                        .padding(14)
                        .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                    }

                    (Text("^[\(documents.count) document](inflect: true)")
                        + Text(" · ")
                        + Text("^[\(categories.count) catégorie](inflect: true)"))
                        .appFont(13, .regular, relativeTo: .footnote)
                        .foregroundStyle(Theme.textTertiary)

                    Spacer()

                    PrimaryButton(title: "Exporter vers Fichiers", systemImage: "arrow.down.doc") {
                        prepareExport()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Sauvegarde chiffrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .data,
                defaultFilename: "Sesame-sauvegarde"
            ) { result in
                if case .success = result { dismiss() }
            }
            .alert("Impossible de créer la sauvegarde", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
    }

    private func prepareExport() {
        do {
            let service = ShareService(vault: vault)
            let url = try service.makeBackup(documents: documents, categories: categories, passphrase: passphrase)
            exportDocument = BackupFileDocument(data: try Data(contentsOf: url))
            service.cleanUpStaging()
            showExporter = true
        } catch {
            exportError = true
        }
    }
}

/// Enveloppe FileDocument pour le fileExporter.
struct BackupFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
