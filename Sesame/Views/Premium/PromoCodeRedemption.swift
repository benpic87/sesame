import StoreKit
import SwiftUI

/// Saisie d'un code promotionnel : présente la feuille système d'Apple
/// (codes d'offre de l'App Store), puis annonce le résultat.
///
/// Le code n'est jamais saisi ni vérifié par l'app : Apple exige sa propre
/// feuille, et c'est elle qui garantit qu'un code ne peut être ni inventé,
/// ni réutilisé au-delà de sa limite.
private struct PromoCodeRedemption: ViewModifier {
    @Environment(StoreService.self) private var store
    @Binding var isPresented: Bool
    let onUnlocked: () -> Void

    @State private var outcome: PromoCodeOutcome?

    private var alertTitle: LocalizedStringKey {
        outcome == .unlocked ? "Premium débloqué" : "Saisie du code indisponible"
    }

    func body(content: Content) -> some View {
        content
            .offerCodeRedemption(isPresented: $isPresented) { result in
                Task { @MainActor in
                    let outcome = await store.completePromoCodeRedemption(result)
                    // Feuille fermée sans déblocage : rien à annoncer.
                    if outcome != .notRedeemed {
                        self.outcome = outcome
                    }
                }
            }
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { outcome != nil },
                    set: { if !$0 { outcome = nil } }
                ),
                presenting: outcome
            ) { outcome in
                Button("OK", role: .cancel) {
                    if outcome == .unlocked { onUnlocked() }
                }
            } message: { outcome in
                if outcome == .unlocked {
                    Text("Votre code a été accepté. Votre coffre est désormais illimité.")
                } else {
                    Text("Réessayez plus tard. Vous pouvez aussi utiliser votre code dans l'App Store, depuis votre compte.")
                }
            }
    }
}

extension View {
    /// Présente la saisie d'un code promotionnel quand `isPresented` passe à
    /// `true` ; `onUnlocked` est appelé une fois le déblocage confirmé.
    func promoCodeRedemption(
        isPresented: Binding<Bool>,
        onUnlocked: @escaping () -> Void = {}
    ) -> some View {
        modifier(PromoCodeRedemption(isPresented: isPresented, onUnlocked: onUnlocked))
    }
}
