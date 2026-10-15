import Foundation
import Observation
import StoreKit

/// Freemium : le coffre gratuit est limité à 3 documents ; l'achat unique
/// « Sésame Premium » (non consommable, StoreKit 2) débloque le coffre
/// illimité. Aucun SDK tiers — seule l'infrastructure App Store est utilisée.
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

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}

enum StoreError: Error {
    /// Produit introuvable : App Store injoignable, ou fichier StoreKit
    /// absent du schéma en développement.
    case productUnavailable
}
