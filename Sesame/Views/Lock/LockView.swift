import SwiftUI

/// Écran 1 — Déverrouillage : Face ID par défaut, repli PIN puis mot de passe.
struct LockView: View {
    @Environment(AuthService.self) private var auth
    @State private var showPINEntry = false
    @State private var attemptedBiometrics = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                SesameLogo(diameter: 76)
                    .padding(.bottom, 22)

                Text("Sésame")
                    .appFont(30, .heavy, relativeTo: .largeTitle, tracking: -0.03)
                    .foregroundStyle(Theme.textPrimary)

                Text("Simple. Privé. Tout reste ici, sur votre téléphone.")
                    .appFont(15, .regular, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    ExampleChip(label: "Passeports")
                    ExampleChip(label: "Ordonnances")
                    ExampleChip(label: "Contrats")
                }
                .padding(.top, 18)

                Spacer()

                PrimaryButton(
                    title: "Déverrouiller avec Face ID",
                    systemImage: "faceid"
                ) {
                    Task { await tryBiometrics() }
                }

                Button("Code PIN ou mot de passe") {
                    showPINEntry = true
                }
                .appFont(15, .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
                .padding(.top, 8)

                Text("Verrouillage automatique après \(Int(auth.autoLockInterval)) s d'inactivité")
                    .appFont(12, .regular, relativeTo: .caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 16)
            }
            .padding(32)
        }
        .sheet(isPresented: $showPINEntry) {
            PINEntryView()
        }
        .task {
            // Face ID proposé automatiquement à l'arrivée sur l'écran.
            guard !attemptedBiometrics else { return }
            attemptedBiometrics = true
            await tryBiometrics()
        }
    }

    private func tryBiometrics() async {
        let success = await auth.unlockWithBiometrics()
        // Échec, refus ou fallback choisi dans la boîte Face ID : proposer le PIN.
        if !success {
            showPINEntry = true
        }
    }
}

private struct ExampleChip: View {
    let label: LocalizedStringKey

    var body: some View {
        Text(label)
            .appFont(13, .semibold, relativeTo: .footnote)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surfaceSecondary, in: Capsule())
    }
}
