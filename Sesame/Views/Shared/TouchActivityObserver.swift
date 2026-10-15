import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Signale chaque toucher dans la fenêtre sans jamais l'intercepter.
/// Remplace un `DragGesture(minimumDistance: 0)` posé à la racine, qui sous
/// iOS 18+ avale les touchers des boutons UIKit (bouton retour, barre d'outils).
struct TouchActivityObserver: UIViewRepresentable {
    let onTouch: () -> Void

    func makeUIView(context: Context) -> ObserverView {
        ObserverView(onTouch: onTouch)
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.recognizer.onTouch = onTouch
    }

    /// Vue invisible qui installe le détecteur sur sa fenêtre : ainsi les
    /// feuilles et plein écrans présentés au-dessus sont aussi couverts.
    final class ObserverView: UIView {
        let recognizer: PassiveTouchRecognizer

        init(onTouch: @escaping () -> Void) {
            recognizer = PassiveTouchRecognizer(onTouch: onTouch)
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) n'est pas pris en charge")
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            recognizer.view?.removeGestureRecognizer(recognizer)
            newWindow?.addGestureRecognizer(recognizer)
        }
    }
}

/// Détecteur qui échoue dès le premier toucher : il ne retarde, n'annule
/// ni ne bloque aucun autre geste ou bouton.
final class PassiveTouchRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouch: () -> Void

    init(onTouch: @escaping () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
