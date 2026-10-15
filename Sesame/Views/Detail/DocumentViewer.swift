import PDFKit
import SwiftUI
import UIKit

/// Visualiseur plein écran : image zoomable (pincer, double-toucher) ou PDF
/// complet. Les données déchiffrées restent en mémoire, jamais sur disque.
struct DocumentViewer: View {
    @Environment(\.dismiss) private var dismiss

    let type: DocumentType
    let data: Data

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            switch type {
            case .image:
                if let image = UIImage(data: data) {
                    ZoomableImageView(image: image)
                        .ignoresSafeArea()
                }
            case .pdf:
                PDFPreview(data: data)
                    .ignoresSafeArea(edges: .bottom)
            case .note:
                EmptyView()
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .statusBarHidden()
    }
}

/// Image dans un `UIScrollView` : zoom natif, recentrage, double-toucher.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    static let maximumZoomScale: CGFloat = 6
    static let doubleTapZoomScale: CGFloat = 2.5

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView(image: image)
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        if view.imageView.image !== image {
            view.imageView.image = image
            view.setNeedsLayout()
        }
    }

    final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
        let imageView = UIImageView()

        init(image: UIImage) {
            super.init(frame: .zero)
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            addSubview(imageView)

            delegate = self
            minimumZoomScale = 1
            maximumZoomScale = ZoomableImageView.maximumZoomScale
            bouncesZoom = true
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            contentInsetAdjustmentBehavior = .never
            backgroundColor = .black

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTap)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) n'est pas pris en charge")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // À zoom 1, l'image occupe tout l'écran (proportions conservées).
            if zoomScale == minimumZoomScale {
                imageView.frame = CGRect(origin: .zero, size: bounds.size)
                contentSize = bounds.size
            }
            centerImage()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        /// Garde l'image centrée quand elle est plus petite que l'écran.
        private func centerImage() {
            let horizontal = max(0, (bounds.width - contentSize.width) / 2)
            let vertical = max(0, (bounds.height - contentSize.height) / 2)
            contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            if zoomScale > minimumZoomScale {
                setZoomScale(minimumZoomScale, animated: true)
            } else {
                let point = recognizer.location(in: imageView)
                let scale = ZoomableImageView.doubleTapZoomScale
                let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
                let rect = CGRect(
                    x: point.x - size.width / 2,
                    y: point.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                zoom(to: rect, animated: true)
            }
        }
    }
}
