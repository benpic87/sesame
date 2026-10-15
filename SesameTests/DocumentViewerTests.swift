import UIKit
import XCTest
@testable import Sesame

final class DocumentViewerTests: XCTestCase {
    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
    }

    func testImageCanBeZoomedUpToSixTimes() {
        let view = ZoomableImageView.ZoomingScrollView(image: makeImage())

        XCTAssertEqual(view.minimumZoomScale, 1)
        XCTAssertEqual(view.maximumZoomScale, 6)
        XCTAssertTrue(view.viewForZooming(in: view) === view.imageView)
    }

    func testImageFillsScreenAtNormalZoom() {
        let view = ZoomableImageView.ZoomingScrollView(image: makeImage())
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.layoutIfNeeded()

        XCTAssertEqual(view.imageView.frame.size, view.bounds.size)
        XCTAssertEqual(view.imageView.contentMode, .scaleAspectFit)
    }

    func testZoomedImageReturnsToNormalSize() {
        let view = ZoomableImageView.ZoomingScrollView(image: makeImage())
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.layoutIfNeeded()

        view.setZoomScale(3, animated: false)
        XCTAssertEqual(view.zoomScale, 3, accuracy: 0.01)

        view.setZoomScale(view.minimumZoomScale, animated: false)
        XCTAssertEqual(view.zoomScale, 1, accuracy: 0.01)
    }
}
