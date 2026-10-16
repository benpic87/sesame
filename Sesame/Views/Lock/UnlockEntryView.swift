import SwiftUI

/// Saisie de déverrouillage intégrée à l'écran de verrouillage : PIN
/// 6 chiffres, ou mot de passe si défini. Toujours visible, même pendant
/// ou après une tentative Face ID.
struct UnlockEntryView: View {
    @Environment(AuthService.self) private var auth

    @State private var pin = ""
    @State private var showError = false
    @State private var usePassword = false
    @State private var password = ""

    var body: some View {
        if usePassword {
            passwordEntry
        } else {
            pinEntry
        }
    }

    private var pinEntry: some View {
        VStack(spacing: 20) {
            Text("Entrez votre code PIN")
                .appFont(20, .bold, relativeTo: .title3, tracking: -0.02)
                .foregroundStyle(Theme.textPrimary)

            PINDots(count: pin.count, isError: showError)

            if auth.isThrottled, let lockoutUntil = auth.lockoutUntil {
                Text("Trop de tentatives. Réessayez à \(lockoutUntil.formatted(date: .omitted, time: .shortened)).")
                    .appFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.alert)
            } else if showError {
                Text("Code incorrect")
                    .appFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.alert)
            }

            PINPad(
                onDigit: { digit in
                    guard pin.count < 6 else { return }
                    showError = false
                    pin.append(digit)
                    if pin.count == 6 {
                        submitPIN()
                    }
                },
                onDelete: {
                    if !pin.isEmpty { pin.removeLast() }
                }
            )

            if auth.hasPassword {
                Button("Utiliser le mot de passe") {
                    usePassword = true
                }
                .appFont(15, .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
            }
        }
    }

    private var passwordEntry: some View {
        VStack(spacing: 20) {
            Text("Mot de passe")
                .appFont(20, .bold, relativeTo: .title3, tracking: -0.02)
                .foregroundStyle(Theme.textPrimary)

            SecureField("Mot de passe", text: $password)
                .textContentType(.password)
                .padding(14)
                .background(Theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                .submitLabel(.go)
                .onSubmit(submitPassword)

            if showError {
                Text("Mot de passe incorrect")
                    .appFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Theme.alert)
            }

            PrimaryButton(title: "Déverrouiller") {
                submitPassword()
            }

            Button("Revenir au code PIN") {
                usePassword = false
                showError = false
            }
            .appFont(15, .semibold, relativeTo: .subheadline)
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
        }
    }

    private func submitPIN() {
        if !auth.unlock(pin: pin) {
            showError = true
            pin = ""
        }
    }

    private func submitPassword() {
        if !auth.unlock(password: password) {
            showError = true
            password = ""
        }
    }
}

/// Les 6 pastilles du PIN.
struct PINDots: View {
    let count: Int
    var isError = false

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? (isError ? Theme.alert : Theme.accent) : Theme.surfaceSecondary)
                    .frame(width: 14, height: 14)
            }
        }
        .accessibilityLabel("Code PIN, \(count) chiffres sur 6 saisis")
    }
}

/// Pavé numérique personnalisé (cibles ≥ 44 pt).
struct PINPad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        PINKey(key: key) {
                            if key == "⌫" {
                                onDelete()
                            } else if !key.isEmpty {
                                onDigit(key)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PINKey: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                } else {
                    Text(key)
                }
            }
            .appFont(24, .semibold, relativeTo: .title2)
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 76, height: 76)
            .background(key.isEmpty ? Color.clear : Theme.surfaceSecondary, in: Circle())
        }
        .disabled(key.isEmpty)
        .accessibilityLabel(key == "⌫" ? Text("Effacer") : Text(key))
    }
}
