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

    init(modelContext: ModelContext, crypto: CryptoService = CryptoService()) {
        self.modelContext = modelContext
        self.crypto = crypto

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        vaultDirectory = support.appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)

        // Jamais dans les sauvegardes iCloud/iTunes.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var dir = vaultDirectory
        try? dir.setResourceValues(values)
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
        expiresAt: Date? = nil
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
