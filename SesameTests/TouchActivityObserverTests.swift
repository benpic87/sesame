import UIKit
import XCTest
@testable import Sesame

final class TouchActivityObserverTests: XCTestCase {
    /// Le détecteur ne doit jamais retenir les touchers : sinon les boutons
    /// UIKit (bouton retour des Réglages) cessent de répondre.
    func testRecognizerNeverInterceptsTouches() {
        let recognizer = PassiveTouchRecognizer(onTouch: {})

        XCTAssertFalse(recognizer.cancelsTouchesInView)
        XCTAssertFalse(recognizer.delaysTouchesBegan)
        XCTAssertFalse(recognizer.delaysTouchesEnded)
        XCTAssertTrue(recognizer.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()))
    }

    func testTouchReportsActivity() {
        var touches = 0
        let recognizer = PassiveTouchRecognizer { touches += 1 }

        recognizer.touchesBegan([], with: UIEvent())

        XCTAssertEqual(touches, 1)
    }

    func testObserverInstallsRecognizerOnItsWindow() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let observer = TouchActivityObserver.ObserverView(onTouch: {})

        window.addSubview(observer)
        XCTAssertTrue(window.gestureRecognizers?.contains(observer.recognizer) == true)

        observer.removeFromSuperview()
        XCTAssertFalse(window.gestureRecognizers?.contains(observer.recognizer) == true)
    }
}
