import SwiftUI

/// Écran 5 — Onboarding en 3 étapes :
/// promesse locale-only → Face ID / PIN → premières catégories.
struct OnboardingView: View {
    @Environment(AuthService.self) private var auth
    @Environment(VaultStore.self) private var vault
    @AppStorage("onboarding-done") private var onboardingDone = false

    @State private var step = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressDots(current: step, total: 3)
                    .padding(.top, 24)

                switch step {
                case 0: PromiseStep { step = 1 }
                case 1: SecurityStep { step = 2 }
                default: CategoriesStep { finish() }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private func finish() {
        onboardingDone = true
        auth.lock()
    }
}

/// Pastilles de progression (active : 22×6 indigo).
private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.accent : Theme.border)
                    .frame(width: index == current ? 22 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}

// MARK: Étape 1 — Promesse

private struct PromiseStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Vos documents,\nseulement ici.")
                .appFont(34, .heavy, relativeTo: .largeTitle, tracking: -0.03)
                .foregroundStyle(Theme.textPrimary)

            Text("Sésame garde vos passeports, cartes et papiers importants chiffrés sur votre téléphone. Pas de compte, pas de nuage, pas de trace.")
                .appFont(16, .regular, relativeTo: .body)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 14) {
                BenefitRow(icon: "lock.shield.fill", label: "Chiffrement sur l'appareil")
                BenefitRow(icon: "icloud.slash.fill", label: "Aucun serveur, aucun compte")
                BenefitRow(icon: "square.and.arrow.up.circle.fill", label: "Partage AirDrop chiffré")
            }
            .padding(.top, 28)

            Spacer()

            PrimaryButton(title: "Commencer") { onContinue() }

            Text("Étape suivante : choisir Face ID ou un code PIN")
                .appFont(12, .regular, relativeTo: .caption)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(label)
                .appFont(15.5, .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: Étape 2 — Face ID / PIN

private struct SecurityStep: View {
    @Environment(AuthService.self) private var auth
    let onContinue: () -> Void

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var isConfirming = false
    @State private var mismatch = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isConfirming ? "Confirmez votre code" : "Choisissez un code PIN")
                .appFont(28, .heavy, relativeTo: .title, tracking: -0.03)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 32)

            Text("Le code à 6 chiffres déverrouille votre coffre si Face ID n'est pas disponible.")
                .appFont(15, .regular, relativeTo: .subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            PINDots(count: (isConfirming ? confirmPIN : pin).count, isError: mismatch)

            if mismatch {
                Text("Les codes ne correspondent pas")
                    .appFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.alert)
            }

            PINPad(
                onDigit: { digit in
                    mismatch = false
                    if isConfirming {
                        guard confirmPIN.count < 6 else { return }
                        confirmPIN.append(digit)
                        if confirmPIN.count == 6 { validate() }
                    } else {
                        guard pin.count < 6 else { return }
                        pin.append(digit)
                        if pin.count == 6 { isConfirming = true }
                    }
                },
                onDelete: {
                    if isConfirming {
                        if !confirmPIN.isEmpty { confirmPIN.removeLast() }
                    } else {
                        if !pin.isEmpty { pin.removeLast() }
                    }
                }
            )

            Spacer()
        }
    }

    private func validate() {
        guard confirmPIN == pin else {
            mismatch = true
            pin = ""
            confirmPIN = ""
            isConfirming = false
            return
        }
        auth.setPIN(pin)
        auth.faceIDEnabled = auth.biometricsAvailable
        onContinue()
    }
}

// MARK: Étape 3 — Premières catégories

private struct CategoriesStep: View {
    @Environment(VaultStore.self) private var vault
    let onFinish: () -> Void

    private static let suggestions: [(name: String.LocalizationValue, token: CategoryColorToken)] = [
        ("Identité", .indigo),
        ("Santé", .green),
        ("Voyage", .amber),
        ("Finances", .pink),
    ]

    @State private var selected: Set<Int> = [0, 1, 2, 3]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vos premières catégories")
                .appFont(28, .heavy, relativeTo: .title, tracking: -0.03)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 32)

            Text("Un document peut porter plusieurs étiquettes. Vous pourrez en créer d'autres à tout moment.")
                .appFont(15, .regular, relativeTo: .subheadline)
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 10) {
                ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    let isOn = selected.contains(index)
                    Button {
                        if isOn {
                            selected.remove(index)
                        } else {
                            selected.insert(index)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(suggestion.token.main)
                                .frame(width: 14, height: 14)
                            Text(String(localized: suggestion.name))
                                .appFont(15.5, .semibold, relativeTo: .subheadline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isOn ? Theme.accent : Theme.dashed)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                                .fill(Theme.surface)
                                .strokeBorder(isOn ? Theme.accent : Theme.border, lineWidth: isOn ? 2 : 1)
                        )
                    }
                }
            }
            .padding(.top, 8)

            Spacer()

            PrimaryButton(title: "Créer mon coffre") {
                for (index, suggestion) in Self.suggestions.enumerated() where selected.contains(index) {
                    vault.createCategory(name: String(localized: suggestion.name), colorToken: suggestion.token)
                }
                onFinish()
            }
            .padding(.bottom, 8)
        }
    }
}
