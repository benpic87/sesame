import Foundation

/// Prépare les fichiers à partager via la share sheet native.
/// Deux modes : archive chiffrée par mot de passe (.sesame) ou copie en clair
/// temporaire pour l'envoi AirDrop simple.
final class ShareService {
    private let vault: VaultStore

    /// Répertoire temporaire des fichiers de partage, nettoyé après usage.
    private let stagingDirectory: URL

    init(vault: VaultStore) {
        self.vault = vault
        stagingDirectory = Self.stagingURL
        try? FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
    }

    private static var stagingURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SesameShare", isDirectory: true)
    }

    /// Purge au lancement : aucune copie en clair ne doit survivre à un crash
    /// ou à une fermeture pendant un partage.
    static func purgeStaging() {
        try? FileManager.default.removeItem(at: stagingURL)
    }

    /// Archive chiffrée AES-256 protégée par le mot de passe généré.
    /// Format `.sesame` : conteneur documenté dans le README (magic + sel + AES-GCM).
    func makeEncryptedArchive(for document: Document, passphrase: String) throws -> URL {
        let payload = try vault.decryptedData(for: document)
        let container = try vault.crypto.encrypt(payload, passphrase: passphrase)
        let url = stagingDirectory.appendingPathComponent(sanitizedName(document.name) + ".sesame")
        try container.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Copie déchiffrée temporaire pour AirDrop simple (chiffré en transit par
    /// AirDrop, lisible dès réception). À supprimer après le partage.
    func makePlainCopy(for document: Document) throws -> URL {
        let payload = try vault.decryptedData(for: document)
        let url = stagingDirectory
            .appendingPathComponent(sanitizedName(document.name))
            .appendingPathExtension(document.originalExtension)
        try payload.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Sauvegarde chiffrée manuelle : toutes les métadonnées + contenus dans un
    /// seul conteneur protégé par phrase de passe, à exporter vers Fichiers.
    func makeBackup(documents: [Document], categories: [Category], passphrase: String) throws -> URL {
        struct BackupDocument: Codable {
            var name: String
            var type: String
            var addedAt: Date
            var expiresAt: Date?
            var tagIDs: [UUID]
            var fileExtension: String
            var contentBase64: String
        }
        struct BackupCategory: Codable {
            var id: UUID
            var name: String
            var colorToken: String
        }
        struct Backup: Codable {
            var version: Int
            var exportedAt: Date
            var categories: [BackupCategory]
            var documents: [BackupDocument]
        }

        let backup = Backup(
            version: 1,
            exportedAt: .now,
            categories: categories.map { .init(id: $0.id, name: $0.name, colorToken: $0.colorTokenRaw) },
            documents: try documents.map { document in
                .init(
                    name: document.name,
                    type: document.typeRaw,
                    addedAt: document.addedAt,
                    expiresAt: document.expiresAt,
                    tagIDs: document.tagIDs,
                    fileExtension: document.originalExtension,
                    contentBase64: try vault.decryptedData(for: document).base64EncodedString()
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(backup)
        let container = try vault.crypto.encrypt(json, passphrase: passphrase)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = stagingDirectory
            .appendingPathComponent("Sesame-sauvegarde-\(formatter.string(from: .now)).sesamebackup")
        try container.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Supprime les copies temporaires après fermeture de la share sheet.
    func cleanUpStaging() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: stagingDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func sanitizedName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }
}
