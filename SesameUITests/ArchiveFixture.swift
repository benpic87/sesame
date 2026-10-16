import CommonCrypto
import CryptoKit
import Foundation

/// Fabrique une archive `.sesame` v2 comme le fait l'app (le test d'interface
/// n'a pas accès au code de l'app) : "SESAME01" ‖ sel ‖ AES-GCM(JSON), clé
/// PBKDF2-HMAC-SHA256 à 210 000 itérations.
enum ArchiveFixture {
    static func make(name: String, text: String, passphrase: String) throws -> URL {
        let iso = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_760_000_000))
        let payload: [String: Any] = [
            "version": 1,
            "exportedAt": iso,
            "categories": [],
            "documents": [[
                "name": name,
                "type": "note",
                "addedAt": iso,
                "tagIDs": [],
                "fileExtension": "txt",
                "contentBase64": Data(text.utf8).base64EncodedString(),
            ]],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)

        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(passphrase: passphrase, salt: salt)
        let sealed = try AES.GCM.seal(json, using: key).combined!

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).sesame")
        try (Data("SESAME01".utf8) + salt + sealed).write(to: url)
        return url
    }

    private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        var derived = Data(count: 32)
        let password = Array(passphrase.utf8).map { Int8(bitPattern: $0) }
        _ = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), password, password.count,
                    saltPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 210_000,
                    derivedPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), 32
                )
            }
        }
        return SymmetricKey(data: derived)
    }
}
