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
