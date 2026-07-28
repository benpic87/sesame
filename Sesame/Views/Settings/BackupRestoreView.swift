import SwiftUI
import UniformTypeIdentifiers

/// Restauration d'une sauvegarde `.sesamebackup` : choisir le fichier,
/// saisir la phrase de récupération, fusionner dans le coffre.
struct BackupRestoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault

    @State private var showFilePicker = false
    @State private var backupData: Data?
    @State private var backupFileName: String?
    @State private var passphrase = ""
    @State private var restoring = false
    @State private var summary: VaultStore.RestoreSummary?
    @State private var errorMessage: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Choisissez le fichier exporté depuis Sésame, puis saisissez la phrase de récupération notée lors de l'export.")
                        .appFont(14.5, .regular, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        showFilePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: backupData == nil ? "doc.badge.plus" : "doc.fill")
                                .foregroundStyle(Theme.accent)
                            Text(backupFileName.map { LocalizedStringKey($0) } ?? "Sélectionner la sauvegarde…")
                                .appFont(15, .semibold, relativeTo: .subheadline)
                                .foregroundStyle(backupData == nil ? Theme.accent : Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous)
                                .fill(Theme.surface)
                                .strokeBorder(
                                    backupData == nil ? Theme.dashed : Theme.border,
                                    style: backupData == nil
                                        ? StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                        : StrokeStyle(lineWidth: 1)
                                )
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phrase de récupération")
                            .appFont(12.5, .semibold, relativeTo: .caption)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.textTertiary)
                        TextField("corail-lampe-92-nuit", text: $passphrase)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .appFont(13.5, .semibold, relativeTo: .footnote)
                            .foregroundStyle(Theme.alert)
                    }

                    if let summary {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("Documents restaurés : \(summary.documentsRestored)")
                            } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            }
                            if summary.duplicatesSkipped > 0 {
                                Text("Doublons ignorés : \(summary.duplicatesSkipped)")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if summary.categoriesAdded > 0 {
                                Text("Catégories ajoutées : \(summary.categoriesAdded)")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .appFont(14.5, .semibold, relativeTo: .subheadline)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    Spacer()

                    if summary == nil {
                        PrimaryButton(title: "Restaurer", systemImage: "arrow.up.doc") {
                            restore()
                        }
                        .disabled(backupData == nil || passphrase.isEmpty || restoring)
                        .opacity(backupData == nil || passphrase.isEmpty || restoring ? 0.5 : 1)
                    } else {
                        PrimaryButton(title: "Terminé") { dismiss() }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Restaurer une sauvegarde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                backupData = try? Data(contentsOf: url)
                backupFileName = url.lastPathComponent
                errorMessage = nil
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
    }

    private func restore() {
        guard let backupData else { return }
        restoring = true
        errorMessage = nil
        defer { restoring = false }
        do {
            summary = try vault.restoreBackup(
                backupData,
                passphrase: passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch CryptoError.wrongPassphrase {
            errorMessage = "Phrase de récupération incorrecte"
        } catch {
            errorMessage = "Fichier de sauvegarde invalide"
        }
    }
}
