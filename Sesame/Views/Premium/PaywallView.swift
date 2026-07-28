import SwiftUI

/// Écran de vente Sésame Premium : coffre illimité, achat unique.
/// Présenté quand la limite gratuite (2 documents) est atteinte,
/// ou depuis les Réglages.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store

    @State private var purchasing = false
    @State private var purchaseError = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.dashed)
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)

                Spacer()

                SesameLogo(diameter: 64)
                    .padding(.bottom, 16)

                Text(verbatim: "Sésame Premium")
                    .appFont(28, .heavy, relativeTo: .title, tracking: -0.03)
                    .foregroundStyle(Theme.textPrimary)

                Text("Le coffre gratuit est limité à 2 documents. Débloquez un coffre illimité, pour toujours.")
                    .appFont(15, .regular, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 14) {
                    PremiumBenefitRow(
                        icon: "infinity",
                        title: "Documents illimités",
                        subtitle: "Ajoutez autant de documents que nécessaire"
                    )
                    PremiumBenefitRow(
                        icon: "checkmark.seal.fill",
                        title: "Achat unique",
                        subtitle: "Pas d'abonnement, pas de publicité"
                    )
                    PremiumBenefitRow(
                        icon: "lock.iphone",
                        title: "Toujours 100 % local",
                        subtitle: "Vos données ne quittent jamais l'appareil"
                    )
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .padding(.top, 22)

                Spacer()

                PrimaryButton(title: buyButtonTitle) {
                    purchase()
                }
                .disabled(purchasing)
                .opacity(purchasing ? 0.6 : 1)

                Button("Restaurer mes achats") {
                    Task {
                        await store.restorePurchases()
                        if store.isPremium { dismiss() }
                    }
                }
                .appFont(14, .semibold, relativeTo: .footnote)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.radiusSheet)
        .alert("Achat impossible pour le moment", isPresented: $purchaseError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var buyButtonTitle: LocalizedStringKey {
        if let price = store.premiumProduct?.displayPrice {
            "Débloquer pour \(price)"
        } else {
            "Débloquer Premium"
        }
    }

    private func purchase() {
        purchasing = true
        Task {
            defer { purchasing = false }
            do {
                if try await store.purchasePremium() {
                    dismiss()
                }
            } catch {
                purchaseError = true
            }
        }
    }
}

private struct PremiumBenefitRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(15.5, .bold, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .appFont(13, .regular, relativeTo: .footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
