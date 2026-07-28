import Foundation
import Observation
import StoreKit

/// Freemium : le coffre gratuit est limité à 2 documents ; l'achat unique
/// « Sésame Premium » (non consommable, StoreKit 2) débloque le coffre
/// illimité. Aucun SDK tiers — seule l'infrastructure App Store est utilisée.
@Observable
final class StoreService {
    static let premiumProductID = "app.sesame.premium"

    /// Nombre de documents autorisés sans achat.
    static let freeDocumentLimit = 2

    private(set) var isPremium = false
    private(set) var premiumProduct: Product?

    private var updatesTask: Task<Void, Never>?

    init() {
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
        premiumProduct = try? await Product.products(for: [Self.premiumProductID]).first
    }

    @MainActor
    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                premium = true
            }
        }
        isPremium = premium
    }

    /// Retourne `true` si l'achat a abouti.
    @MainActor
    func purchasePremium() async throws -> Bool {
        if premiumProduct == nil {
            await loadProduct()
        }
        guard let product = premiumProduct else { return false }

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
