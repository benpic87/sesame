import Foundation
import Observation

/// Archive `.sesame` reçue (AirDrop, Fichiers, Mail…), en attente du mot de
/// passe. Le fichier est lu dès l'ouverture : l'app n'en garde aucune copie.
@Observable
final class IncomingArchive {
    struct Pending: Identifiable {
        let id = UUID()
        let data: Data
        let fileName: String
    }

    var pending: Pending?

    func receive(_ url: URL) {
        guard url.pathExtension.lowercased() == "sesame" else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }

        pending = Pending(data: data, fileName: url.deletingPathExtension().lastPathComponent)

        // Copie déposée par iOS dans Documents/Inbox : supprimée aussitôt.
        if url.pathComponents.contains("Inbox") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
