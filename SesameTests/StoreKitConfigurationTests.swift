import StoreKit
import StoreKitTest
import XCTest
@testable import Sesame

/// Vérifie que `Sesame.storekit` (boutique de test utilisée par ⌘R) est
/// lisible et expose bien le produit Premium attendu par l'app.
final class StoreKitConfigurationTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        // Fichier à la racine du dépôt, deux niveaux au-dessus de ce test.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sesame.storekit")
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        await waitForTestStore()
    }

    /// Juste après sa création, la boutique de test peut répondre vide le
    /// temps que le simulateur la prenne en compte : on attend (10 s max).
    private func waitForTestStore() async {
        for _ in 0..<20 {
            if let products = try? await Product.products(for: [StoreService.premiumProductID]),
               !products.isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
        super.tearDown()
    }

    func testConfigurationExposesPremiumProduct() async throws {
        let products = try await Product.products(for: [StoreService.premiumProductID])

        let premium = try XCTUnwrap(products.first, "Sesame.storekit ne fournit pas \(StoreService.premiumProductID)")
        XCTAssertEqual(premium.type, .nonConsumable)
    }

    @MainActor
    func testPurchaseUnlocksPremium() async throws {
        let store = StoreService()

        let purchased = try await store.purchasePremium()

        XCTAssertTrue(purchased)
        XCTAssertTrue(store.isPremium)
    }
}
