import SwiftUI
import UIKit
import XCTest
@testable import Sesame

/// Couleurs de catégories : assez nombreuses, compatibles avec les noms déjà
/// en base, et toujours lisibles (contraste WCAG AA ≥ 4,5:1).
final class CategoryColorTests: XCTestCase {
    func testTwelveColorsAreAvailable() {
        XCTAssertEqual(CategoryColorToken.allCases.count, 12)
    }

    /// Les catégories existantes gardent leur couleur (nom brut stocké en base).
    func testExistingStoredColorsStillResolve() {
        for raw in ["indigo", "green", "amber", "pink"] {
            XCTAssertNotNil(CategoryColorToken(rawValue: raw), raw)
        }
    }

    func testColoredTextIsReadableOnTintAndWhite() {
        for token in CategoryColorToken.allCases {
            XCTAssertGreaterThanOrEqual(contrast(token.ink, token.tint), 4.5, "\(token) sur sa teinte")
            XCTAssertGreaterThanOrEqual(contrast(token.ink, .white), 4.5, "\(token) sur blanc / texte blanc dessus")
        }
    }

    // MARK: Contraste WCAG 2.x

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
