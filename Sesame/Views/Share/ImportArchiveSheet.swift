import SwiftData
import SwiftUI

/// Ouverture d'une archive `.sesame` reçue : saisie du mot de passe communiqué
/// par l'expéditeur, puis ajout du document au coffre (rechiffré localement).
/// Affichée en couche plein écran par RootView ; `onClose` la retire.
struct ImportArchiveSheet: View {
    @Environment(VaultStore.self) private var vault
    @Environment(StoreService.self) private var store
    @Query private var documents: [Document]

    let pending: IncomingArchive.Pending
    let onClose: () -> Void

    @State private var passphrase = ""
    @State private var errorMessage: LocalizedStringKey?
    @State private var showPaywall = false

    private var canAdd: Bool {
        store.canAddDocument(currentCount: documents.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "lock.doc.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.accent)

                    Text("Document chiffré reçu")
                        .appFont(24, .heavy, relativeTo: .title2, tracking: -0.02)
                        .foregroundStyle(Theme.textPrimary)

                    Text(verbatim: pending.fileName)
                        .appFont(15, .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    if canAdd {
                        Text("Entrez le mot de passe communiqué par l'expéditeur.")
                            .appFont(15, .regular, relativeTo: .subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("Mot de passe", text: $passphrase)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(importArchive)
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous)
                                    .strokeBorder(errorMessage == nil ? Theme.border : Theme.alert, lineWidth: 1)
                            )

                        if let errorMessage {
                            Text(errorMessage)
                                .appFont(13, .semibold, relativeTo: .footnote)
                                .foregroundStyle(Theme.alert)
                        }

                        PrimaryButton(title: "Importer dans le coffre", systemImage: "lock.fill") {
                            importArchive()
                        }
                        .disabled(passphrase.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        // Recevoir compte comme ajouter : même limite que l'import.
                        Text("Le coffre gratuit est limité à 3 documents. Débloquez un coffre illimité, pour toujours.")
                            .appFont(15, .regular, relativeTo: .subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        PrimaryButton(title: "Passer à Premium", systemImage: "sparkles") {
                            showPaywall = true
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onClose() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func importArchive() {
        let trimmed = passphrase.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try vault.importSharedArchive(pending.data, passphrase: trimmed, fileName: pending.fileName)
            onClose()
        } catch CryptoError.wrongPassphrase {
            errorMessage = "Mot de passe incorrect"
        } catch {
            errorMessage = "Ce fichier n'est pas une archive Sésame lisible."
        }
    }
}
