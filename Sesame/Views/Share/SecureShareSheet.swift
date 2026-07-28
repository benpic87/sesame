import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {
    /// Copie sensible : locale à l'appareil (pas de presse-papiers universel),
    /// effacée automatiquement après 2 minutes.
    func setSensitive(_ string: String) {
        setItems(
            [[UTType.utf8PlainText.identifier: string]],
            options: [
                .localOnly: true,
                .expirationDate: Date.now.addingTimeInterval(120),
            ]
        )
    }
}

/// Écran 7 — Partage sécurisé (bottom sheet) : archive chiffrée avec mot de
/// passe généré, ou envoi AirDrop simple. Les deux passent par la share sheet.
struct SecureShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault

    let document: Document

    enum Mode {
        case encrypted, plain
    }

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var mode: Mode = .encrypted
    @State private var passphrase = PassphraseGenerator.generate()
    @State private var copied = false
    @State private var shareItem: ShareItem?
    @State private var shareError = false

    private var shareService: ShareService {
        ShareService(vault: vault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Theme.dashed)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Partage sécurisé")
                .appFont(22, .heavy, relativeTo: .title2, tracking: -0.02)
                .foregroundStyle(Theme.textPrimary)

            Text("\(document.name) · \(Format.fileSize(document.sizeBytes))")
                .appFont(14, .regular, relativeTo: .subheadline)
                .foregroundStyle(Theme.textSecondary)

            ShareModeOption(
                title: "Chiffré avec mot de passe",
                subtitle: "Le fichier est verrouillé. Communiquez le mot de passe de vive voix ou par un autre canal.",
                isSelected: mode == .encrypted
            ) { mode = .encrypted }

            ShareModeOption(
                title: "Envoi AirDrop simple",
                subtitle: "Déjà chiffré en transit par AirDrop, lisible dès réception.",
                isSelected: mode == .plain
            ) { mode = .plain }

            if mode == .encrypted {
                passphraseBox
            }

            PrimaryButton(title: "Continuer vers AirDrop", systemImage: "square.and.arrow.up") {
                prepareShare()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Theme.radiusSheet)
        .presentationBackground(Theme.background)
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url]) {
                shareService.cleanUpStaging()
                dismiss()
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Impossible de préparer le partage", isPresented: $shareError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var passphraseBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mot de passe généré")
                .appFont(12.5, .semibold, relativeTo: .caption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)

            HStack {
                Text(passphrase)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Button {
                    UIPasteboard.general.setSensitive(passphrase)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Text(copied ? "Copié ✓" : "Copier")
                        .appFont(14, .bold, relativeTo: .footnote)
                        .foregroundStyle(Theme.accent)
                        .frame(minWidth: 44, minHeight: 34)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
        }
    }

    private func prepareShare() {
        do {
            switch mode {
            case .encrypted:
                shareItem = ShareItem(url: try shareService.makeEncryptedArchive(for: document, passphrase: passphrase))
            case .plain:
                shareItem = ShareItem(url: try shareService.makePlainCopy(for: document))
            }
        } catch {
            shareError = true
        }
    }
}

private struct ShareModeOption: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.dashed)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .appFont(15.5, .bold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .appFont(13, .regular, relativeTo: .footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.surface)
                    .strokeBorder(
                        isSelected ? Theme.accent : Theme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

/// Share sheet native (AirDrop, Fichiers, etc.).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
