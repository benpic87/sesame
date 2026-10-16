import CryptoKit
import SwiftData
import XCTest
@testable import Sesame

/// Partage chiffré `.sesame` : exporté par un appareil, ouvert dans Sésame sur
/// un autre (clé maîtresse différente) avec le mot de passe communiqué.
@MainActor
final class SharedArchiveTests: XCTestCase {
    private var directories: [String] = []

    override func tearDown() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        for name in directories {
            try? FileManager.default.removeItem(at: support.appendingPathComponent(name))
        }
        super.tearDown()
    }

    /// Coffre indépendant : base en mémoire, clé et dossier qui lui sont propres.
    private func makeVault() throws -> (VaultStore, ModelContainer) {
        let container = try ModelContainer(
            for: Document.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let name = "Vault-SharedArchiveTests-\(UUID().uuidString)"
        directories.append(name)
        let vault = VaultStore(
            modelContext: container.mainContext,
            crypto: CryptoService(masterKey: SymmetricKey(size: .bits256)),
            directoryName: name
        )
        return (vault, container)
    }

    private func documents(in container: ModelContainer) throws -> [Document] {
        try container.mainContext.fetch(FetchDescriptor<Document>())
    }

    func testArchiveOpensOnAnotherDeviceWithNameAndType() throws {
        let (sender, senderContainer) = try makeVault()
        defer { withExtendedLifetime(senderContainer) {} }  // base vivante jusqu'à la fin
        let pdf = Data("%PDF-1.7 passeport".utf8)
        let original = try sender.importDocument(data: pdf, name: "Passeport – Camille", type: .pdf, fileExtension: "pdf")
        let url = try ShareService(vault: sender).makeEncryptedArchive(for: original, passphrase: "corail-lampe-92-nuit")
        let archive = try Data(contentsOf: url)
        XCTAssertEqual(url.pathExtension, "sesame")
        XCTAssertNil(archive.range(of: pdf), "Le contenu ne doit pas apparaître en clair dans l'archive")

        let (receiver, receiverContainer) = try makeVault()
        try receiver.importSharedArchive(archive, passphrase: "corail-lampe-92-nuit", fileName: "fichier reçu")

        let received = try XCTUnwrap(try documents(in: receiverContainer).first)
        XCTAssertEqual(received.name, "Passeport – Camille")
        XCTAssertEqual(received.type, .pdf)
        XCTAssertEqual(received.originalExtension, "pdf")
        XCTAssertEqual(try receiver.decryptedData(for: received), pdf)
    }

    func testWrongPassphraseIsRejectedAndAddsNothing() throws {
        let (sender, senderContainer) = try makeVault()
        defer { withExtendedLifetime(senderContainer) {} }  // base vivante jusqu'à la fin
        let original = try sender.importDocument(data: Data("secret".utf8), name: "Note", type: .note, fileExtension: "txt")
        let archive = try Data(contentsOf: ShareService(vault: sender)
            .makeEncryptedArchive(for: original, passphrase: "corail-lampe-92-nuit"))

        let (receiver, receiverContainer) = try makeVault()
        XCTAssertThrowsError(try receiver.importSharedArchive(archive, passphrase: "mauvais-mot-11-passe", fileName: "x")) { error in
            XCTAssertEqual(error as? CryptoError, .wrongPassphrase)
        }
        XCTAssertTrue(try documents(in: receiverContainer).isEmpty)
    }

    /// Archives d'avant la v2 : contenu brut sans nom ni type.
    func testLegacyRawArchiveIsStillImported() throws {
        let (receiver, receiverContainer) = try makeVault()
        let pdf = Data("%PDF-1.4 ancienne archive".utf8)
        let legacy = try receiver.crypto.encrypt(pdf, passphrase: "corail-lampe-92-nuit")

        try receiver.importSharedArchive(legacy, passphrase: "corail-lampe-92-nuit", fileName: "Ordonnance")

        let received = try XCTUnwrap(try documents(in: receiverContainer).first)
        XCTAssertEqual(received.name, "Ordonnance")
        XCTAssertEqual(received.type, .pdf)
        XCTAssertEqual(try receiver.decryptedData(for: received), pdf)
    }

    func testContentTypeIsDeducedFromBytes() {
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).jpegData(withCompressionQuality: 0.8) { _ in }

        XCTAssertEqual(VaultStore.sniffType(of: Data("%PDF-1.7".utf8)).0, .pdf)
        XCTAssertEqual(VaultStore.sniffType(of: jpeg).0, .image)
        XCTAssertEqual(VaultStore.sniffType(of: Data("code wifi : 1234".utf8)).0, .note)
    }

    func testIncomingArchiveIgnoresOtherFiles() throws {
        let incoming = IncomingArchive()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("photo.jpg")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        incoming.receive(url)

        XCTAssertNil(incoming.pending)
    }

    func testIncomingArchiveKeepsNameAndContent() throws {
        let incoming = IncomingArchive()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Passeport.sesame")
        try Data("conteneur".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        incoming.receive(url)

        XCTAssertEqual(incoming.pending?.fileName, "Passeport")
        XCTAssertEqual(incoming.pending?.data, Data("conteneur".utf8))
    }
}
