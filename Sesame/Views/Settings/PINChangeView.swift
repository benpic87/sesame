import SwiftUI

/// Modification du code PIN : vérification de l'ancien, saisie double du nouveau.
struct PINChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    private enum Step {
        case verifyCurrent, enterNew, confirmNew

        var title: LocalizedStringKey {
            switch self {
            case .verifyCurrent: "Code PIN actuel"
            case .enterNew: "Nouveau code PIN"
            case .confirmNew: "Confirmez le nouveau code"
            }
        }
    }

    @State private var step: Step = .verifyCurrent
    @State private var pin = ""
    @State private var newPIN = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(step.title)
                        .appFont(24, .heavy, relativeTo: .title2, tracking: -0.02)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 32)

                    PINDots(count: pin.count, isError: showError)

                    if showError {
                        Text(step == .verifyCurrent ? "Code incorrect" : "Les codes ne correspondent pas")
                            .appFont(13, .semibold, relativeTo: .footnote)
                            .foregroundStyle(Theme.alert)
                    }

                    PINPad(
                        onDigit: { digit in
                            guard pin.count < 6 else { return }
                            showError = false
                            pin.append(digit)
                            if pin.count == 6 { advance() }
                        },
                        onDelete: {
                            if !pin.isEmpty { pin.removeLast() }
                        }
                    )

                    Spacer()
                }
                .padding(32)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
    }

    private func advance() {
        switch step {
        case .verifyCurrent:
            if auth.verify(pin: pin) {
                step = .enterNew
                pin = ""
            } else {
                showError = true
                pin = ""
            }
        case .enterNew:
            newPIN = pin
            pin = ""
            step = .confirmNew
        case .confirmNew:
            if pin == newPIN {
                auth.setPIN(pin)
                dismiss()
            } else {
                showError = true
                pin = ""
                newPIN = ""
                step = .enterNew
            }
        }
    }
}
