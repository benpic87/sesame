import SwiftUI
import VisionKit

/// Scanner VisionKit avec recadrage automatique des bords.
/// Une page → image JPEG ; plusieurs pages → PDF assemblé.
struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let completion: (Result<PendingImport, Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            defer { parent.dismiss() }
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            guard !images.isEmpty else { return }

            let suggestedName = String(localized: "Scan du \(Date.now.formatted(date: .abbreviated, time: .shortened))")

            if images.count == 1, let jpeg = images[0].jpegData(compressionQuality: 0.85) {
                parent.completion(.success(PendingImport(
                    data: jpeg, type: .image, fileExtension: "jpg", suggestedName: suggestedName
                )))
            } else {
                let pdfData = Self.makePDF(from: images)
                parent.completion(.success(PendingImport(
                    data: pdfData, type: .pdf, fileExtension: "pdf", suggestedName: suggestedName
                )))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.completion(.failure(error))
            parent.dismiss()
        }

        static func makePDF(from images: [UIImage]) -> Data {
            let renderer = UIGraphicsPDFRenderer(bounds: .zero)
            return renderer.pdfData { context in
                for image in images {
                    let bounds = CGRect(origin: .zero, size: image.size)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)
                }
            }
        }
    }
}

/// Appareil photo natif ; la photo n'est jamais enregistrée dans la pellicule.
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let completion: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let jpeg = image.jpegData(compressionQuality: 0.85) {
                parent.completion(jpeg)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
