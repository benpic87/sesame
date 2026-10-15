import CommonCrypto
import CryptoKit
import Foundation
import Security

enum CryptoError: Error {
    case invalidContainer
    case wrongPassphrase
    case keyDerivationFailed
    /// Trousseau inaccessible pour l'instant (appareil verrouillé…) :
    /// l'opération échoue, mais aucune clé n'est créée ni effacée.
    case masterKeyUnavailable
}

/// Chiffrement du coffre : AES-GCM avec une clé maîtresse de 256 bits gardée
/// dans le Keychain. Chaque document et chaque vignette est chiffré
/// individuellement ; rien n'est écrit en clair sur le disque.
final class CryptoService {
    private static let masterKeyKeychainKey = "master-key.v1"

    /// En-tête des conteneurs protégés par phrase de passe (export/partage).
    private static let containerMagic = Data("SESAME01".utf8)
    private static let pbkdf2Rounds: UInt32 = 210_000
    private static let saltLength = 16

    private let keychain: KeychainStoring?
    private var cachedMasterKey: SymmetricKey?
    private let keyLock = NSLock()

    /// La clé maîtresse est chargée au premier usage, pas au lancement : l'app
    /// peut démarrer (pré-lancement iOS) alors que le trousseau est encore
    /// inaccessible. Elle n'est créée que si le trousseau confirme son absence.
    init(keychain: KeychainStoring = KeychainStore()) {
        self.keychain = keychain
    }

    /// Initialisation directe pour les tests (aucun Keychain requis).
    init(masterKey: SymmetricKey) {
        keychain = nil
        cachedMasterKey = masterKey
    }

    // MARK: Clé maîtresse (fichiers du coffre)

    func encrypt(_ plaintext: Data) throws -> Data {
        try AES.GCM.seal(plaintext, using: masterKey()).combined!
    }

    func decrypt(_ ciphertext: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: masterKey())
    }

    private func masterKey() throws -> SymmetricKey {
        keyLock.lock()
        defer { keyLock.unlock() }
        if let cachedMasterKey { return cachedMasterKey }
        guard let keychain else { throw CryptoError.masterKeyUnavailable }
        let key = try Self.loadOrCreateMasterKey(in: keychain)
        cachedMasterKey = key
        return key
    }

    /// Ne recrée JAMAIS une clé sur une erreur de lecture : une nouvelle clé
    /// rendrait illisibles tous les documents chiffrés avec l'ancienne.
    static func loadOrCreateMasterKey(in keychain: KeychainStoring) throws -> SymmetricKey {
        let stored: Data?
        do {
            stored = try keychain.read(masterKeyKeychainKey)
        } catch {
            throw CryptoError.masterKeyUnavailable
        }
        if let stored {
            return SymmetricKey(data: stored)
        }
        // Absence confirmée : premier lancement. La clé n'est utilisée que si
        // son enregistrement a réussi (ajout seul, jamais d'écrasement).
        let key = SymmetricKey(size: .bits256)
        do {
            try keychain.add(key.withUnsafeBytes { Data($0) }, for: masterKeyKeychainKey)
        } catch {
            throw CryptoError.masterKeyUnavailable
        }
        return key
    }

    func encryptToFile(_ plaintext: Data, at url: URL) throws {
        let sealed = try encrypt(plaintext)
        try sealed.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func decryptFile(at url: URL) throws -> Data {
        try decrypt(Data(contentsOf: url))
    }

    // MARK: Phrase de passe (export et partage sécurisé)

    /// Conteneur autoportant : magic ‖ sel (16 o) ‖ AES-GCM(combined).
    /// La clé est dérivée de la phrase par PBKDF2-HMAC-SHA256.
    func encrypt(_ plaintext: Data, passphrase: String) throws -> Data {
        var salt = Data(count: Self.saltLength)
        let saltResult = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, $0.baseAddress!)
        }
        guard saltResult == errSecSuccess else { throw CryptoError.keyDerivationFailed }

        let key = try Self.deriveKey(passphrase: passphrase, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key).combined!
        return Self.containerMagic + salt + sealed
    }

    func decrypt(_ container: Data, passphrase: String) throws -> Data {
        let magicEnd = Self.containerMagic.count
        let saltEnd = magicEnd + Self.saltLength
        guard container.count > saltEnd,
              container.prefix(magicEnd) == Self.containerMagic
        else { throw CryptoError.invalidContainer }

        let salt = container.subdata(in: magicEnd..<saltEnd)
        let sealed = container.subdata(in: saltEnd..<container.count)
        let key = try Self.deriveKey(passphrase: passphrase, salt: salt)
        do {
            let box = try AES.GCM.SealedBox(combined: sealed)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.wrongPassphrase
        }
    }

    static func deriveKey(passphrase: String, salt: Data) throws -> SymmetricKey {
        var derived = Data(count: 32)
        let passwordBytes = Array(passphrase.utf8)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
                    saltPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    pbkdf2Rounds,
                    derivedPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), 32
                )
            }
        }
        guard status == Int32(kCCSuccess) else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }

    /// Empreinte PBKDF2 pour vérifier PIN et mot de passe sans les stocker.
    /// Format : sel (16 o) ‖ empreinte (32 o).
    static func hashSecret(_ secret: String) -> Data {
        var salt = Data(count: saltLength)
        _ = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!)
        }
        let key = (try? deriveKey(passphrase: secret, salt: salt)) ?? SymmetricKey(size: .bits256)
        return salt + key.withUnsafeBytes { Data($0) }
    }

    static func verifySecret(_ secret: String, against stored: Data) -> Bool {
        guard stored.count == saltLength + 32 else { return false }
        let salt = stored.prefix(saltLength)
        let expected = stored.suffix(32)
        guard let key = try? deriveKey(passphrase: secret, salt: Data(salt)) else { return false }
        let candidate = key.withUnsafeBytes { Data($0) }
        // Comparaison à temps constant.
        return HMAC<SHA256>.authenticationCode(for: candidate, using: SymmetricKey(data: salt))
            == HMAC<SHA256>.authenticationCode(for: expected, using: SymmetricKey(data: salt))
    }
}
