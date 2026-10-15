import Foundation
import Security

/// Accès Keychain minimal, injectable pour les tests.
protocol KeychainStoring {
    func data(for key: String) -> Data?
    func set(_ data: Data, for key: String)
    func delete(_ key: String)

    /// `nil` uniquement si l'entrée n'existe pas ; lève une erreur si le
    /// trousseau est inaccessible (appareil verrouillé…) : ne jamais confondre.
    func read(_ key: String) throws -> Data?
    /// Ajoute sans jamais écraser une entrée existante.
    func add(_ data: Data, for key: String) throws
}

enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

/// Implémentation Keychain réelle. Toutes les entrées sont protégées par
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` : jamais migrées sur un
/// autre appareil, inaccessibles téléphone verrouillé.
struct KeychainStore: KeychainStoring {
    private let service = "app.sesame.vault"

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func set(_ data: Data, for key: String) {
        delete(key)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    func read(_ key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedStatus(status) }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func add(_ data: Data, for key: String) throws {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }
}

/// Keychain en mémoire pour les tests unitaires.
final class InMemoryKeychain: KeychainStoring {
    private var storage: [String: Data] = [:]
    func data(for key: String) -> Data? { storage[key] }
    func set(_ data: Data, for key: String) { storage[key] = data }
    func delete(_ key: String) { storage[key] = nil }
    func read(_ key: String) throws -> Data? { storage[key] }
    func add(_ data: Data, for key: String) throws {
        guard storage[key] == nil else { throw KeychainError.unexpectedStatus(errSecDuplicateItem) }
        storage[key] = data
    }
}
