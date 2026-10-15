import XCTest
@testable import Sesame

/// Blocage du PIN persistant et progressif.
final class PINLockoutTests: XCTestCase {
    func testLockoutSurvivesAppRelaunch() {
        let keychain = InMemoryKeychain()
        let auth = AuthService(keychain: keychain)
        auth.setPIN("123456")
        for _ in 0..<5 { _ = auth.unlock(pin: "000000") }
        XCTAssertTrue(auth.isThrottled)

        let relaunched = AuthService(keychain: keychain)

        XCTAssertTrue(relaunched.isThrottled, "Relancer l'app ne doit pas lever le blocage")
        XCTAssertFalse(relaunched.unlock(pin: "123456"))
    }

    func testLockoutGrowsWithRepeatedFailures() {
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 4), 0)
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 5), 30)
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 6), 0)
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 10), 60)
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 15), 120)
        XCTAssertEqual(AuthService.lockoutDuration(afterFailures: 500), AuthService.maximumLockout)
    }

    func testFailuresKeepCountingAcrossRelaunches() {
        let keychain = InMemoryKeychain()
        let auth = AuthService(keychain: keychain)
        auth.setPIN("123456")
        for _ in 0..<3 { _ = auth.unlock(pin: "000000") }

        let relaunched = AuthService(keychain: keychain)
        XCTAssertEqual(relaunched.failedAttempts, 3)
        for _ in 0..<2 { _ = relaunched.unlock(pin: "000000") }

        XCTAssertTrue(relaunched.isThrottled, "3 + 2 erreurs doivent atteindre le palier de 5")
    }

    func testSuccessfulUnlockClearsLockoutState() {
        let keychain = InMemoryKeychain()
        let auth = AuthService(keychain: keychain)
        auth.setPIN("123456")
        for _ in 0..<3 { _ = auth.unlock(pin: "000000") }

        XCTAssertTrue(auth.unlock(pin: "123456"))

        let relaunched = AuthService(keychain: keychain)
        XCTAssertEqual(relaunched.failedAttempts, 0)
        XCTAssertNil(relaunched.lockoutUntil)
    }
}

/// Métadonnées (noms, dates, étiquettes) hors des sauvegardes.
final class MetadataStorageTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetadataStorageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testStoreLivesInsideVaultDirectory() {
        let vault = root.appendingPathComponent("Vault")

        let url = VaultStore.metadataStoreURL(in: vault)

        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path, vault.standardizedFileURL.path)
    }

    func testLegacyStoreIsMovedIntoVault() throws {
        let vault = root.appendingPathComponent("Vault")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            try Data("base\(suffix)".utf8).write(to: root.appendingPathComponent("default.store\(suffix)"))
        }

        let url = VaultStore.metadataStoreURL(in: vault)

        for suffix in ["", "-wal", "-shm"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("default.store\(suffix)").path))
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: url.path + suffix)), Data("base\(suffix)".utf8))
        }
    }

    func testExistingStoreIsNeverOverwrittenByLegacyOne() throws {
        let vault = root.appendingPathComponent("Vault")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("actuelle".utf8).write(to: vault.appendingPathComponent("Sesame.store"))
        try Data("ancienne".utf8).write(to: root.appendingPathComponent("default.store"))

        let url = VaultStore.metadataStoreURL(in: vault)

        XCTAssertEqual(try Data(contentsOf: url), Data("actuelle".utf8))
    }

    func testVaultDirectoryIsExcludedFromBackups() throws {
        let name = "Vault-Test-\(UUID().uuidString)"
        let directory = VaultStore.preparedDirectory(named: name)
        defer { try? FileManager.default.removeItem(at: directory) }

        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
