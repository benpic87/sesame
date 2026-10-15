import SwiftData
import SwiftUI

/// Écran 8 — Réglages : sécurité, données, effacement du coffre.
struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VaultStore.self) private var vault
    @Environment(StoreService.self) private var store
    @Query private var documents: [Document]
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var showPINChange = false
    @State private var showBackup = false
    @State private var showRestore = false
    @State private var showPaywall = false
    @State private var confirmWipe1 = false
    @State private var confirmWipe2 = false
    @State private var restoreResult: RestoreResult?

    private enum RestoreResult {
        case restored, nothingFound
    }

    var body: some View {
        @Bindable var auth = auth

        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsGroup(title: "Sésame Premium") {
                        if store.isPremium {
                            HStack {
                                Text("Coffre illimité débloqué")
                                    .appFont(15.5, .regular, relativeTo: .subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                        } else {
                            SettingsLinkRow(
                                title: "Passer à Premium",
                                subtitle: "Coffre illimité, achat unique",
                                value: ""
                            ) {
                                showPaywall = true
                            }
                        }
                        Divider().overlay(Theme.border)
                        // Toujours présent (exigence App Store) : c'est justement
                        // après une réinstallation que l'app se croit gratuite.
                        SettingsLinkRow(
                            title: "Restaurer mes achats",
                            subtitle: store.isPremium
                                ? "Premium déjà actif sur cet appareil"
                                : "Déjà acheté ? Récupérez Premium sans repayer",
                            value: "",
                            isEnabled: !store.isPremium
                        ) {
                            Task {
                                await store.restorePurchases()
                                restoreResult = store.isPremium ? .restored : .nothingFound
                            }
                        }
                    }

                    SettingsGroup(title: "Sécurité") {
                        SettingsToggleRow(
                            title: "Face ID",
                            isOn: $auth.faceIDEnabled,
                            disabled: !auth.biometricsAvailable
                        )
                        Divider().overlay(Theme.border)
                        SettingsLinkRow(title: "Code PIN", value: "Modifier") {
                            showPINChange = true
                        }
                        Divider().overlay(Theme.border)
                        autoLockRow
                    }

                    SettingsGroup(title: "Données") {
                        NavigationLink {
                            CategoryManagerView()
                        } label: {
                            SettingsRowLabel(title: "Gérer les catégories", value: "\(categories.count)")
                        }
                        Divider().overlay(Theme.border)
                        SettingsLinkRow(
                            title: "Sauvegarde chiffrée locale",
                            subtitle: "Export manuel vers Fichiers, jamais automatique",
                            value: ""
                        ) {
                            showBackup = true
                        }
                        Divider().overlay(Theme.border)
                        SettingsLinkRow(
                            title: "Restaurer une sauvegarde",
                            subtitle: "Depuis un fichier .sesamebackup",
                            value: ""
                        ) {
                            showRestore = true
                        }
                        Divider().overlay(Theme.border)
                        SettingsLinkRow(title: "Langue", value: languageName) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    Button("Effacer tout le coffre…") {
                        confirmWipe1 = true
                    }
                    .appFont(15.5, .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.alert)
                    .frame(maxWidth: .infinity, minHeight: 44)

                    Text("Sésame 1.0 · aucune donnée collectée")
                        .appFont(12, .regular, relativeTo: .caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        // L'accueil masque sa barre : on la réaffiche ici pour le bouton retour.
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showPINChange) { PINChangeView() }
        .sheet(isPresented: $showBackup) { BackupExportView() }
        .sheet(isPresented: $showRestore) { BackupRestoreView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(
            restoreResult == .restored ? "Premium restauré" : "Aucun achat trouvé",
            isPresented: Binding(
                get: { restoreResult != nil },
                set: { if !$0 { restoreResult = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if restoreResult == .restored {
                Text("Votre coffre illimité est de nouveau actif.")
            } else {
                Text("Aucun achat Premium n'est associé à cet identifiant Apple.")
            }
        }
        .alert("Effacer tout le coffre ?", isPresented: $confirmWipe1) {
            Button("Continuer", role: .destructive) { confirmWipe2 = true }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tous les documents chiffrés seront supprimés de cet appareil. Cette action est irréversible.")
        }
        .alert("Dernière confirmation", isPresented: $confirmWipe2) {
            Button("Tout effacer définitivement", role: .destructive) {
                vault.wipeVault()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("^[\(documents.count) document](inflect: true) seront définitivement effacés. Aucune récupération possible.")
        }
    }

    private var autoLockRow: some View {
        @Bindable var auth = auth
        return Menu {
            ForEach([30.0, 60, 120, 300], id: \.self) { seconds in
                Button(autoLockLabel(seconds)) {
                    auth.autoLockInterval = seconds
                }
            }
        } label: {
            SettingsRowLabel(title: "Verrouillage auto", value: autoLockLabel(auth.autoLockInterval))
        }
    }

    private func autoLockLabel(_ seconds: TimeInterval) -> String {
        seconds < 60
            ? String(localized: "\(Int(seconds)) secondes")
            : seconds == 60
                ? String(localized: "60 secondes")
                : String(localized: "\(Int(seconds / 60)) minutes")
    }

    private var languageName: String {
        let identifier = Locale.current.language.languageCode?.identifier ?? "fr"
        return Locale.current.localizedString(forLanguageCode: identifier)?.capitalized
            ?? String(localized: "Français")
    }
}

// MARK: Composants réglages (groupes iOS, cartes blanches radius 18)

struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .appFont(12.5, .semibold, relativeTo: .caption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 16)

            VStack(spacing: 0) {
                content
            }
            .card()
        }
    }
}

struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(15.5, .regular, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .appFont(12.5, .regular, relativeTo: .caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .appFont(15, .regular, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct SettingsLinkRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let value: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title: title, subtitle: subtitle, value: value)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    var disabled = false

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .appFont(15.5, .regular, relativeTo: .subheadline)
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accent)
        .disabled(disabled)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
