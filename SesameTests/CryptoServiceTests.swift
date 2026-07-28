import CryptoKit
import XCTest
@testable import Sesame

final class CryptoServiceTests: XCTestCase {
    private var crypto: CryptoService!

    override func setUp() {
        super.setUp()
        crypto = CryptoService(masterKey: SymmetricKey(size: .bits256))
    }

    // MARK: Clé maîtresse

    func testEncryptDecryptRoundTrip() throws {
        let plaintext = Data("Passeport – Camille".utf8)
        let ciphertext = try crypto.encrypt(plaintext)

        XCTAssertNotEqual(ciphertext, plaintext, "Le chiffré ne doit pas être le clair")
        XCTAssertEqual(try crypto.decrypt(ciphertext), plaintext)
    }

    func testDecryptWithWrongKeyFails() throws {
        let ciphertext = try crypto.encrypt(Data("secret".utf8))
        let otherCrypto = CryptoService(masterKey: SymmetricKey(size: .bits256))

        XCTAssertThrowsError(try otherCrypto.decrypt(ciphertext))
    }

    func testTamperedCiphertextFails() throws {
        var ciphertext = try crypto.encrypt(Data("secret".utf8))
        ciphertext[ciphertext.count - 1] ^= 0xFF

        XCTAssertThrowsError(try crypto.decrypt(ciphertext))
    }

    func testFileRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".enc")
        defer { try? FileManager.default.removeItem(at: url) }

        let plaintext = Data((0..<10_000).map { UInt8($0 % 256) })
        try crypto.encryptToFile(plaintext, at: url)

        // Rien en clair sur le disque.
        let onDisk = try Data(contentsOf: url)
        XCTAssertNotEqual(onDisk, plaintext)
        XCTAssertNil(onDisk.range(of: Data(plaintext.prefix(64))))

        XCTAssertEqual(try crypto.decryptFile(at: url), plaintext)
    }

    func testMasterKeyIsPersistedInKeychain() {
        let keychain = InMemoryKeychain()
        let first = CryptoService(keychain: keychain)
        let second = CryptoService(keychain: keychain)

        let ciphertext = try! first.encrypt(Data("persisté".utf8))
        XCTAssertEqual(try? second.decrypt(ciphertext), Data("persisté".utf8),
                       "Deux instances doivent partager la même clé maîtresse")
    }

    // MARK: Phrase de passe (partage / sauvegarde)

    func testPassphraseContainerRoundTrip() throws {
        let plaintext = Data("contenu du document".utf8)
        let container = try crypto.encrypt(plaintext, passphrase: "corail-lampe-92-nuit")

        XCTAssertEqual(try crypto.decrypt(container, passphrase: "corail-lampe-92-nuit"), plaintext)
    }

    func testPassphraseContainerWrongPassphraseFails() throws {
        let container = try crypto.encrypt(Data("secret".utf8), passphrase: "corail-lampe-92-nuit")

        XCTAssertThrowsError(try crypto.decrypt(container, passphrase: "mauvais-mot-11-passe")) { error in
            XCTAssertEqual(error as? CryptoError, .wrongPassphrase)
        }
    }

    func testInvalidContainerIsRejected() {
        XCTAssertThrowsError(try crypto.decrypt(Data("pas un conteneur".utf8), passphrase: "x")) { error in
            XCTAssertEqual(error as? CryptoError, .invalidContainer)
        }
    }

    // MARK: Empreintes PIN / mot de passe

    func testSecretHashVerification() {
        let stored = CryptoService.hashSecret("123456")

        XCTAssertTrue(CryptoService.verifySecret("123456", against: stored))
        XCTAssertFalse(CryptoService.verifySecret("654321", against: stored))
        XCTAssertFalse(CryptoService.verifySecret("123456", against: Data()))
    }

    func testSecretHashUsesRandomSalt() {
        XCTAssertNotEqual(CryptoService.hashSecret("123456"), CryptoService.hashSecret("123456"),
                          "Deux empreintes du même secret doivent différer (sel aléatoire)")
    }
}

extension CryptoError: Equatable {
    public static func == (lhs: CryptoError, rhs: CryptoError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidContainer, .invalidContainer),
             (.wrongPassphrase, .wrongPassphrase),
             (.keyDerivationFailed, .keyDerivationFailed):
            true
        default:
            false
        }
    }
}
