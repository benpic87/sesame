import SwiftUI

/// Écran 1 — Déverrouillage : PIN directement à l'écran (ou mot de passe),
/// Face ID proposé automatiquement dès que l'app est au premier plan.
struct LockView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var attemptedBiometrics = false

    private var canUseFaceID: Bool {
        auth.faceIDEnabled && auth.biometricsAvailable
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            SesameLogo(diameter: 34)
                            Text("Sésame")
                                .appFont(24, .heavy, relativeTo: .title, tracking: -0.03)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.bottom, 28)

                        UnlockEntryView()

                        if canUseFaceID {
                            Button {
                                Task { _ = await auth.unlockWithBiometrics() }
                            } label: {
                                Label("Déverrouiller avec Face ID", systemImage: "faceid")
                                    .appFont(15, .semibold, relativeTo: .subheadline)
                                    .foregroundStyle(Theme.accent)
                                    .frame(minHeight: 44)
                            }
                            .padding(.top, 8)
                        }

                        Text("Verrouillage automatique après \(Int(auth.autoLockInterval)) s d'inactivité")
                            .appFont(12, .regular, relativeTo: .caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    // Centré verticalement ; défile si l'écran est trop petit.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        // Face ID seulement une fois l'app au premier plan : lancé pendant le
        // retour d'arrière-plan, iOS le refusait et l'écran basculait sur le PIN.
        // En cas d'échec ou d'annulation, rien ne change : le PIN reste là.
        .task(id: scenePhase) {
            guard scenePhase == .active, !attemptedBiometrics, canUseFaceID else { return }
            attemptedBiometrics = true
            _ = await auth.unlockWithBiometrics()
        }
    }
}
