import StoreKit
import XCTest
@testable import Sesame

final class StoreServiceTests: XCTestCase {
    func testFreeLimitIsThreeDocuments() {
        XCTAssertEqual(StoreService.freeDocumentLimit, 3)
    }

    func testFreeVaultAcceptsUpToThreeDocuments() {
        let store = StoreService()

        XCTAssertTrue(store.canAddDocument(currentCount: 0))
        XCTAssertTrue(store.canAddDocument(currentCount: 1))
        XCTAssertTrue(store.canAddDocument(currentCount: 2))
    }

    func testFreeVaultRefusesFourthDocument() {
        let store = StoreService()

        XCTAssertFalse(store.canAddDocument(currentCount: 3))
        XCTAssertFalse(store.canAddDocument(currentCount: 10))
    }

    // MARK: Code promotionnel
    // Identifiant inexistant : aucun droit Premium ne peut exister, quel que
    // soit l'état de la boutique de test laissé par un autre test.

    @MainActor
    func testPromoCodeSheetClosedWithoutRedemptionUnlocksNothing() async {
        let store = StoreService(productID: "app.sesame.inexistant")

        let outcome = await store.completePromoCodeRedemption(
            .success(()), attempts: 2, delay: .milliseconds(10)
        )

        XCTAssertEqual(outcome, .notRedeemed)
        XCTAssertFalse(store.isPremium)
    }

    @MainActor
    func testPromoCodeCancellationIsNotAnError() async {
        let store = StoreService(productID: "app.sesame.inexistant")

        let outcome = await store.completePromoCodeRedemption(.failure(StoreKitError.userCancelled))

        XCTAssertEqual(outcome, .notRedeemed)
    }

    @MainActor
    func testPromoCodeSheetFailureIsReported() async {
        let store = StoreService(productID: "app.sesame.inexistant")

        let outcome = await store.completePromoCodeRedemption(.failure(StoreError.productUnavailable))

        XCTAssertEqual(outcome, .unavailable)
        XCTAssertFalse(store.isPremium)
    }

    /// Produit inconnu de la boutique : l'achat doit échouer bruyamment au
    /// lieu de ne rien faire. (Identifiant inexistant, car une SKTestSession
    /// d'un autre test peut rester active dans le même processus.)
    @MainActor
    func testPurchaseThrowsWhenProductUnavailable() async {
        let store = StoreService(productID: "app.sesame.inexistant")

        do {
            _ = try await store.purchasePremium()
            XCTFail("L'achat aurait dû lever StoreError.productUnavailable")
        } catch StoreError.productUnavailable {
            // Attendu.
        } catch {
            XCTFail("Erreur inattendue : \(error)")
        }
    }
}
