import Foundation
import Observation
import StoreKit

/// Freemium : le coffre gratuit est limité à 3 documents ; l'achat unique
/// « Sésame Premium » (non consommable, StoreKit 2) débloque le coffre
/// illimité. Aucun SDK tiers — seule l'infrastructure App Store est utilisée.
///
/// Un code promotionnel débloque le même produit sans paiement : ce sont les
/// codes d'offre de l'App Store, créés dans App Store Connect et saisis dans
/// la feuille système d'Apple. L'app ne contient donc ni code ni secret à
/// extraire ; Apple valide le code, en limite l'usage et délivre une
/// transaction signée, identique à celle d'un achat (restauration comprise).
@Observable
final class StoreService {
    static let premiumProductID = "app.sesame.premium"

    /// Nombre de documents autorisés sans achat.
    static let freeDocumentLimit = 3

    private(set) var isPremium = false
    private(set) var premiumProduct: Product?

    private var updatesTask: Task<Void, Never>?

    /// Identifiant du produit demandé à StoreKit ; injectable pour les tests.
    let productID: String

    init(productID: String = StoreService.premiumProductID) {
        self.productID = productID
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { @MainActor [weak self] in
            await self?.finishPendingTransactions()
            await self?.refreshEntitlements()
            await self?.loadProduct()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// La limite s'applique uniquement à l'ajout : les documents existants
    /// restent toujours accessibles, même après un remboursement.
    func canAddDocument(currentCount: Int) -> Bool {
        isPremium || currentCount < Self.freeDocumentLimit
    }

    @MainActor
    func loadProduct() async {
        premiumProduct = try? await Product.products(for: [productID]).first
    }

    @MainActor
    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                premium = true
            }
        }
        isPremium = premium
    }

    /// Retourne `true` si l'achat a abouti, `false` s'il est annulé ou en attente.
    /// Lève `StoreError.productUnavailable` si le produit n'a pas pu être chargé,
    /// pour que l'interface puisse l'expliquer au lieu de ne rien faire.
    @MainActor
    func purchasePremium() async throws -> Bool {
        if premiumProduct == nil {
            await loadProduct()
        }
        guard let product = premiumProduct else { throw StoreError.productUnavailable }

        let result = try await product.purchase()
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            isPremium = true
            return true
        case .success(.unverified), .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Clôt les transactions restées en attente (achat ou code promotionnel
    /// validé hors de l'app, ou pendant qu'elle était fermée).
    @MainActor
    func finishPendingTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }

    /// À appeler à la fermeture de la feuille de saisie d'un code promotionnel.
    ///
    /// La feuille d'Apple ne dit pas si un code a été validé : la transaction
    /// arrive à part, parfois avec un léger retard. On interroge donc les
    /// droits plusieurs fois avant de conclure que rien n'a été débloqué.
    /// Un déblocage plus tardif encore reste pris en compte par l'écoute
    /// permanente des transactions.
    @MainActor
    func completePromoCodeRedemption(
        _ result: Result<Void, Error>,
        attempts: Int = 6,
        delay: Duration = .milliseconds(500)
    ) async -> PromoCodeOutcome {
        var sheetFailed = false
        if case .failure(let error) = result {
            if let storeError = error as? StoreKitError, case .userCancelled = storeError {
                return isPremium ? .unlocked : .notRedeemed
            }
            sheetFailed = true
        }

        // Feuille non présentée : une seule vérification, sans attente.
        let tries = sheetFailed ? 1 : max(1, attempts)
        for attempt in 1...tries {
            await finishPendingTransactions()
            await refreshEntitlements()
            if isPremium { return .unlocked }
            if attempt < tries {
                try? await Task.sleep(for: delay)
            }
        }
        return sheetFailed ? .unavailable : .notRedeemed
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}

/// Issue de la saisie d'un code promotionnel.
enum PromoCodeOutcome: Equatable {
    /// Code accepté : Premium est actif.
    case unlocked
    /// Feuille fermée sans déblocage (abandon, code refusé par Apple).
    case notRedeemed
    /// La feuille de saisie n'a pas pu s'afficher.
    case unavailable
}

enum StoreError: Error {
    /// Produit introuvable : App Store injoignable, ou fichier StoreKit
    /// absent du schéma en développement.
    case productUnavailable
}
