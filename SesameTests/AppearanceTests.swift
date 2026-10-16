import XCTest
@testable import Sesame

/// Le design « Pop clair » n'a pas de variante sombre : l'app doit forcer
/// l'apparence claire, sinon iOS en mode sombre affiche la barre d'état et
/// les boutons de navigation en blanc/gris sur le fond clair de l'app.
final class AppearanceTests: XCTestCase {
    func testAppAlwaysUsesLightAppearance() {
        let style = Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle") as? String

        XCTAssertEqual(style, "Light")
    }
}
