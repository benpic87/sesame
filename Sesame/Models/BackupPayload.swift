import Foundation

/// Contenu d'une sauvegarde `.sesamebackup` (v1), une fois le conteneur
/// déchiffré. Le JSON est encodé/décodé avec des dates ISO 8601.
/// ⚠️ Les noms de champs sont le format sur disque : ne pas les renommer,
/// les sauvegardes déjà exportées doivent rester lisibles.
struct BackupPayload: Codable {
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

    var version: Int
    var exportedAt: Date
    var categories: [BackupCategory]
    var documents: [BackupDocument]

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
