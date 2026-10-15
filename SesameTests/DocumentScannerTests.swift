import PDFKit
import XCTest
@testable import Sesame

final class DocumentScannerTests: XCTestCase {
    /// Le simulateur n'a pas de caméra : le scanner doit s'y déclarer
    /// indisponible, sinon VNDocumentCameraViewController() fait planter l'app.
    func testScannerIsUnsupportedOnSimulator() throws {
        #if targetEnvironment(simulator)
        XCTAssertFalse(DocumentScannerView.isSupported)
        #else
        throw XCTSkip("Vérification propre au simulateur")
        #endif
    }

    func testMultiPageScanBecomesOnePDFWithAllPages() throws {
        let pages = (0..<3).map { _ in
            UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
            }
        }

        let data = DocumentScannerView.Coordinator.makePDF(from: pages)
        let pdf = try XCTUnwrap(PDFDocument(data: data))

        XCTAssertEqual(pdf.pageCount, 3)
    }
}
