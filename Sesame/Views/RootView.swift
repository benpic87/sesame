import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VaultStore.self) private var vault
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding-done") private var onboardingDone = false

    var body: some View {
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

            // Masque le contenu dans le sélecteur d'apps (app switcher).
            if scenePhase != .active && onboardingDone {
                PrivacyShieldView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isLocked)
        .onChange(of: auth.isLocked) { _, locked in
            if locked { vault.clearCaches() }
        }
        // Toute interaction repousse l'auto-verrouillage.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in auth.registerActivity() }
                .onEnded { _ in auth.registerActivity() }
        )
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
