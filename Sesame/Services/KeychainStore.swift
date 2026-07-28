import Foundation
import Security

/// Accès Keychain minimal, injectable pour les tests.
protocol KeychainStoring {
    func data(for key: String) -> Data?
    func set(_ data: Data, for key: String)
    func delete(_ key: String)
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
}

/// Keychain en mémoire pour les tests unitaires.
final class InMemoryKeychain: KeychainStoring {
    private var storage: [String: Data] = [:]
    func data(for key: String) -> Data? { storage[key] }
    func set(_ data: Data, for key: String) { storage[key] = data }
    func delete(_ key: String) { storage[key] = nil }
}
