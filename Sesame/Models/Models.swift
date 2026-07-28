import Foundation
import SwiftData

enum DocumentType: String, Codable, CaseIterable {
    case image, pdf, note

    /// Libellé de badge sur les cartes (les images n'en portent pas).
    var badge: String? {
        switch self {
        case .image: nil
        case .pdf: "PDF"
        case .note: "NOTE"
        }
    }
}

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var sizeBytes: Int64
    var addedAt: Date
    var expiresAt: Date?
    /// Modèle étiquettes : un document peut porter plusieurs catégories.
    var tagIDs: [UUID]
    /// Nom du fichier chiffré dans le répertoire du coffre.
    var encryptedFileName: String
    /// Nom de la vignette chiffrée (absente pour les notes).
    var thumbnailFileName: String?
    /// Extension d'origine (jpg, pdf, txt…) pour restituer un fichier lisible au partage.
    var originalExtension: String

    var type: DocumentType {
        DocumentType(rawValue: typeRaw) ?? .image
    }

    init(
        name: String,
        type: DocumentType,
        sizeBytes: Int64,
        addedAt: Date = .now,
        expiresAt: Date? = nil,
        tagIDs: [UUID] = [],
        encryptedFileName: String,
        thumbnailFileName: String? = nil,
        originalExtension: String
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.sizeBytes = sizeBytes
        self.addedAt = addedAt
        self.expiresAt = expiresAt
        self.tagIDs = tagIDs
        self.encryptedFileName = encryptedFileName
        self.thumbnailFileName = thumbnailFileName
        self.originalExtension = originalExtension
    }

    /// Alerte visuelle quand l'expiration approche (moins de 6 mois).
    func isExpiringSoon(reference: Date = .now) -> Bool {
        guard let expiresAt else { return false }
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: reference) ?? reference
        return expiresAt <= sixMonths
    }
}

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorTokenRaw: String
    var createdAt: Date

    var colorToken: CategoryColorToken {
        CategoryColorToken(rawValue: colorTokenRaw) ?? .indigo
    }

    init(name: String, colorToken: CategoryColorToken) {
        self.id = UUID()
        self.name = name
        self.colorTokenRaw = colorToken.rawValue
        self.createdAt = .now
    }
}
