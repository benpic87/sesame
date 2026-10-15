import CryptoKit
import XCTest
@testable import Sesame

/// La clé maîtresse ne doit jamais être recréée ni écrasée sur une erreur de
/// trousseau : sinon tous les documents existants deviendraient illisibles.
final class MasterKeyTests: XCTestCase {
    /// Trousseau dont on contrôle les pannes (appareil verrouillé, etc.).
    private final class ControllableKeychain: KeychainStoring {
        var storage: [String: Data] = [:]
        var readsFail = false
        var addsFail = false
        private(set) var addCount = 0

        func data(for key: String) -> Data? { readsFail ? nil : storage[key] }
        func set(_ data: Data, for key: String) { storage[key] = data }
        func delete(_ key: String) { storage[key] = nil }

        func read(_ key: String) throws -> Data? {
            if readsFail { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
            return storage[key]
        }

        func add(_ data: Data, for key: String) throws {
            addCount += 1
            if addsFail { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
            guard storage[key] == nil else { throw KeychainError.unexpectedStatus(errSecDuplicateItem) }
            storage[key] = data
        }
    }

    func testUnreadableKeychainNeverCreatesOrReplacesKey() throws {
        let keychain = ControllableKeychain()
        let original = try CryptoService(keychain: keychain).encrypt(Data("passeport".utf8))
        let storedKey = keychain.storage

        // Relance alors que le trousseau est inaccessible (appareil verrouillé).
        keychain.readsFail = true
        let relaunched = CryptoService(keychain: keychain)

        XCTAssertThrowsError(try relaunched.encrypt(Data("autre".utf8))) { error in
            XCTAssertEqual(error as? CryptoError, .masterKeyUnavailable)
        }
        XCTAssertEqual(keychain.addCount, 1, "Aucune nouvelle clé ne doit être tentée")
        XCTAssertEqual(keychain.storage, storedKey, "La clé d'origine doit rester intacte")

        // Trousseau de nouveau accessible : les anciens documents se lisent.
        keychain.readsFail = false
        XCTAssertEqual(try relaunched.decrypt(original), Data("passeport".utf8))
    }

    func testKeyIsNotUsedUntilSavedInKeychain() throws {
        let keychain = ControllableKeychain()
        keychain.addsFail = true
        let crypto = CryptoService(keychain: keychain)

        XCTAssertThrowsError(try crypto.encrypt(Data("passeport".utf8)),
                             "Chiffrer avec une clé non enregistrée la perdrait au prochain lancement")
        XCTAssertTrue(keychain.storage.isEmpty)

        // Une fois l'enregistrement possible, la clé sauvegardée est celle utilisée.
        keychain.addsFail = false
        let ciphertext = try crypto.encrypt(Data("passeport".utf8))
        XCTAssertEqual(try CryptoService(keychain: keychain).decrypt(ciphertext), Data("passeport".utf8))
    }

    func testExistingKeyIsNeverOverwritten() throws {
        let keychain = ControllableKeychain()
        let ciphertext = try CryptoService(keychain: keychain).encrypt(Data("passeport".utf8))
        let storedKey = keychain.storage

        for _ in 0..<3 {
            _ = try CryptoService(keychain: keychain).encrypt(Data("x".utf8))
        }

        XCTAssertEqual(keychain.storage, storedKey)
        XCTAssertEqual(try CryptoService(keychain: keychain).decrypt(ciphertext), Data("passeport".utf8))
    }
}
