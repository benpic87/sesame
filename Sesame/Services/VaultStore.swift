import Foundation
import Observation
import SwiftData
import UIKit

/// Source de vérité du coffre : import chiffré, lecture déchiffrée en mémoire,
/// vignettes, catégories, effacement. Aucune donnée en clair n'est écrite sur
/// le disque ; le répertoire du coffre est exclu des sauvegardes.
@Observable
final class VaultStore {
    let crypto: CryptoService
    private let modelContext: ModelContext
    private let thumbnailCache = NSCache<NSString, UIImage>()

    let vaultDirectory: URL

    /// `directoryName` : dossier distinct pour les tests d'interface, afin de
    /// ne jamais toucher au coffre réel de l'appareil.
    init(modelContext: ModelContext, crypto: CryptoService = CryptoService(), directoryName: String = "Vault") {
        self.modelContext = modelContext
        self.crypto = crypto

        vaultDirectory = Self.preparedDirectory(named: directoryName)
    }

    /// Dossier du coffre, créé si besoin et exclu des sauvegardes iCloud et
    /// ordinateur (exclusion héritée par tout son contenu, base comprise).
    static func preparedDirectory(named name: String = "Vault") -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directory = support.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }

    /// Base des métadonnées (noms, dates, étiquettes) rangée dans le coffre,
    /// donc hors sauvegardes. Déplace l'ancienne base `default.store` (placée
    /// à la racine d'Application Support, sauvegardée) au premier lancement.
    static func metadataStoreURL(in directory: URL) -> URL {
        let storeURL = directory.appendingPathComponent("Sesame.store")
        let manager = FileManager.default
        let legacy = directory.deletingLastPathComponent().appendingPathComponent("default.store")
        guard !manager.fileExists(atPath: storeURL.path), manager.fileExists(atPath: legacy.path) else {
            return storeURL
        }
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: legacy.path + suffix)
            let to = URL(fileURLWithPath: storeURL.path + suffix)
            if manager.fileExists(atPath: from.path) {
                try? manager.moveItem(at: from, to: to)
            }
        }
        return storeURL
    }

    // MARK: Import

    /// Chiffre et enregistre un document ; génère et chiffre sa vignette.
    @discardableResult
    func importDocument(
        data: Data,
        name: String,
        type: DocumentType,
        fileExtension: String,
        tagIDs: [UUID] = [],
        expiresAt: Date? = nil,
        addedAt: Date = .now
    ) throws -> Document {
        let fileName = UUID().uuidString + ".enc"
        try crypto.encryptToFile(data, at: vaultDirectory.appendingPathComponent(fileName))

        var thumbnailFileName: String?
        if let thumbnail = Self.makeThumbnail(from: data, type: type),
           let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
            let thumbName = UUID().uuidString + ".thumb.enc"
            try crypto.encryptToFile(thumbnailData, at: vaultDirectory.appendingPathComponent(thumbName))
            thumbnailFileName = thumbName
        }

        let document = Document(
            name: name,
            type: type,
            sizeBytes: Int64(data.count),
            addedAt: addedAt,
            tagIDs: tagIDs,
            encryptedFileName: fileName,
            thumbnailFileName: thumbnailFileName,
            originalExtension: fileExtension
        )
        if let expiresAt { document.expiresAt = expiresAt }
        modelContext.insert(document)
        try modelContext.save()
        return document
    }

    // MARK: Lecture

    /// Contenu déchiffré, uniquement en mémoire.
    func decryptedData(for document: Document) throws -> Data {
        try crypto.decryptFile(at: vaultDirectory.appendingPathComponent(document.encryptedFileName))
    }

    func thumbnail(for document: Document) -> UIImage? {
        guard let name = document.thumbnailFileName else { return nil }
        if let cached = thumbnailCache.object(forKey: name as NSString) { return cached }
        guard let data = try? crypto.decryptFile(at: vaultDirectory.appendingPathComponent(name)),
              let image = UIImage(data: data)
        else { return nil }
        thumbnailCache.setObject(image, forKey: name as NSString)
        return image
    }

    func noteText(for document: Document) -> String {
        guard document.type == .note, let data = try? decryptedData(for: document) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: Mise à jour / suppression

    func updateNote(_ document: Document, text: String) throws {
        let data = Data(text.utf8)
        try crypto.encryptToFile(data, at: vaultDirectory.appendingPathComponent(document.encryptedFileName))
        document.sizeBytes = Int64(data.count)
        try modelContext.save()
    }

    func delete(_ document: Document) {
        try? FileManager.default.removeItem(at: vaultDirectory.appendingPathComponent(document.encryptedFileName))
        if let thumb = document.thumbnailFileName {
            thumbnailCache.removeObject(forKey: thumb as NSString)
            try? FileManager.default.removeItem(at: vaultDirectory.appendingPathComponent(thumb))
        }
        modelContext.delete(document)
        try? modelContext.save()
    }

    /// « Effacer tout le coffre » : documents, fichiers chiffrés et vignettes.
    func wipeVault() {
        let documents = (try? modelContext.fetch(FetchDescriptor<Document>())) ?? []
        for document in documents {
            delete(document)
        }
        thumbnailCache.removeAllObjects()
    }

    // MARK: Catégories

    @discardableResult
    func createCategory(name: String, colorToken: CategoryColorToken) -> Category {
        let category = Category(name: name, colorToken: colorToken)
        modelContext.insert(category)
        try? modelContext.save()
        return category
    }

    func deleteCategory(_ category: Category) {
        // Retire l'étiquette de tous les documents qui la portent.
        let id = category.id
        let documents = (try? modelContext.fetch(FetchDescriptor<Document>())) ?? []
        for document in documents where document.tagIDs.contains(id) {
            document.tagIDs.removeAll { $0 == id }
        }
        modelContext.delete(category)
        try? modelContext.save()
    }

    func save() {
        try? modelContext.save()
    }

    /// À appeler au verrouillage : aucune donnée déchiffrée ne reste en cache.
    func clearCaches() {
        thumbnailCache.removeAllObjects()
    }

    // MARK: Restauration de sauvegarde

    struct RestoreSummary {
        var documentsRestored = 0
        var duplicatesSkipped = 0
        var categoriesAdded = 0
    }

    /// Restaure un fichier `.sesamebackup` : déchiffre le conteneur avec la
    /// phrase de récupération, puis fusionne — les catégories sont rapprochées
    /// par identifiant puis par nom, les documents déjà présents (même nom,
    /// même taille, même date d'ajout) sont ignorés. Chaque document restauré
    /// est rechiffré avec la clé maîtresse locale.
    func restoreBackup(_ container: Data, passphrase: String) throws -> RestoreSummary {
        let json = try crypto.decrypt(container, passphrase: passphrase)
        let backup = try BackupPayload.decoder().decode(BackupPayload.self, from: json)

        var summary = RestoreSummary()
        let existingCategories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let existingDocuments = (try? modelContext.fetch(FetchDescriptor<Document>())) ?? []

        // Catégories : id de la sauvegarde → id local.
        var categoryMap: [UUID: UUID] = [:]
        for backupCategory in backup.categories {
            if existingCategories.contains(where: { $0.id == backupCategory.id }) {
                categoryMap[backupCategory.id] = backupCategory.id
            } else if let sameName = existingCategories.first(where: {
                $0.name.localizedCaseInsensitiveCompare(backupCategory.name) == .orderedSame
            }) {
                categoryMap[backupCategory.id] = sameName.id
            } else {
                let category = Category(
                    name: backupCategory.name,
                    colorToken: CategoryColorToken(rawValue: backupCategory.colorToken) ?? .indigo
                )
                category.id = backupCategory.id
                modelContext.insert(category)
                categoryMap[backupCategory.id] = backupCategory.id
                summary.categoriesAdded += 1
            }
        }

        for backupDocument in backup.documents {
            guard let data = Data(base64Encoded: backupDocument.contentBase64) else {
                throw CryptoError.invalidContainer
            }
            // Doublon : même nom, même taille, date d'ajout à la seconde près
            // (l'ISO 8601 de l'export tronque les fractions de seconde).
            let isDuplicate = existingDocuments.contains {
                $0.name == backupDocument.name
                    && $0.sizeBytes == Int64(data.count)
                    && abs($0.addedAt.timeIntervalSince(backupDocument.addedAt)) < 1
            }
            if isDuplicate {
                summary.duplicatesSkipped += 1
                continue
            }
            try importDocument(
                data: data,
                name: backupDocument.name,
                type: DocumentType(rawValue: backupDocument.type) ?? .image,
                fileExtension: backupDocument.fileExtension,
                tagIDs: backupDocument.tagIDs.compactMap { categoryMap[$0] },
                expiresAt: backupDocument.expiresAt,
                addedAt: backupDocument.addedAt
            )
            summary.documentsRestored += 1
        }

        try modelContext.save()
        return summary
    }

    // MARK: Vignettes

    /// Vignette non chiffrée générée en mémoire, redimensionnée avant chiffrement.
    static func makeThumbnail(from data: Data, type: DocumentType, maxDimension: CGFloat = 480) -> UIImage? {
        switch type {
        case .image:
            guard let image = UIImage(data: data) else { return nil }
            return resize(image, maxDimension: maxDimension)
        case .pdf:
            guard let provider = CGDataProvider(data: data as CFData),
                  let pdf = CGPDFDocument(provider),
                  let page = pdf.page(at: 1)
            else { return nil }
            let box = page.getBoxRect(.mediaBox)
            let scale = maxDimension / max(box.width, box.height)
            let size = CGSize(width: box.width * scale, height: box.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                context.cgContext.drawPDFPage(page)
            }
            return image
        case .note:
            return nil
        }
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
