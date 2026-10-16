import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VaultStore.self) private var vault
    @Environment(IncomingArchive.self) private var incoming
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding-done") private var onboardingDone = false

    var body: some View {
        // Archive reçue, proposée seulement une fois le coffre déverrouillé
        // (reproposée après un verrouillage tant qu'elle n'est pas traitée).
        let pendingImport = onboardingDone && !auth.isLocked ? incoming.pending : nil

        ZStack {
            if !onboardingDone {
                OnboardingView()
            } else if auth.isLocked {
                LockView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }

            // Archive reçue : couche par-dessus l'app plutôt qu'une feuille,
            // qu'iOS refuserait pendant la fermeture du pavé PIN.
            if let pendingImport {
                ImportArchiveSheet(pending: pendingImport) {
                    incoming.pending = nil
                }
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }

            // Masque le contenu dans le sélecteur d'apps (app switcher).
            if scenePhase != .active && onboardingDone {
                PrivacyShieldView()
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isLocked)
        .animation(.easeInOut(duration: 0.25), value: pendingImport?.id)
        .onChange(of: auth.isLocked) { _, locked in
            if locked { vault.clearCaches() }
        }
        // Toute interaction repousse l'auto-verrouillage. Observateur passif
        // au niveau de la fenêtre : un DragGesture ici bloquait le bouton retour.
        .background(TouchActivityObserver { auth.registerActivity() })
    }
}

/// Écran de garde affiché dès que l'app quitte le premier plan.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            SesameLogo(diameter: 76)
        }
    }
}

/// Logo : cercle indigo, carré arrondi blanc centré.
struct SesameLogo: View {
    var diameter: CGFloat = 76

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent)
                .frame(width: diameter, height: diameter)
            RoundedRectangle(cornerRadius: diameter * 0.12, style: .continuous)
                .fill(.white)
                .frame(width: diameter * 0.4, height: diameter * 0.4)
        }
        .accessibilityHidden(true)
    }
}
