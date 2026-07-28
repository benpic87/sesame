import XCTest
@testable import Sesame

final class AutoLockTests: XCTestCase {
    func testPolicyDoesNotLockBeforeInterval() {
        let policy = AutoLockPolicy(interval: 60)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(59)))
    }

    func testPolicyLocksAtInterval() {
        let policy = AutoLockPolicy(interval: 60)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(60)))
        XCTAssertTrue(policy.shouldLock(lastActivity: start, now: start.addingTimeInterval(3_600)))
    }

    func testAuthServiceLocksAfterInactivity() {
        let auth = AuthService(keychain: InMemoryKeychain())
        auth.setPIN("123456")
        XCTAssertTrue(auth.unlock(pin: "123456"))
        XCTAssertFalse(auth.isLocked)

        let unlockTime = auth.lastActivityAt
        auth.lockIfInactive(now: unlockTime.addingTimeInterval(auth.autoLockInterval + 1))

        XCTAssertTrue(auth.isLocked)
    }

    func testActivityPostponesAutoLock() {
        let auth = AuthService(keychain: InMemoryKeychain())
        auth.setPIN("123456")
        XCTAssertTrue(auth.unlock(pin: "123456"))

        let start = auth.lastActivityAt
        // L'utilisateur interagit 30 s plus tard : le compteur repart.
        auth.registerActivity(now: start.addingTimeInterval(30))
        auth.lockIfInactive(now: start.addingTimeInterval(70))

        XCTAssertFalse(auth.isLocked, "L'activité récente doit repousser le verrouillage")
    }

    func testWrongPINDoesNotUnlock() {
        let auth = AuthService(keychain: InMemoryKeychain())
        auth.setPIN("123456")

        XCTAssertFalse(auth.unlock(pin: "000000"))
        XCTAssertTrue(auth.isLocked)
    }

    func testThrottleAfterFiveFailures() {
        let auth = AuthService(keychain: InMemoryKeychain())
        auth.setPIN("123456")

        for _ in 0..<5 {
            XCTAssertFalse(auth.unlock(pin: "000000"))
        }

        XCTAssertTrue(auth.isThrottled)
        XCTAssertFalse(auth.unlock(pin: "123456"),
                       "Le bon PIN doit être refusé pendant le verrouillage temporaire")
        XCTAssertTrue(auth.isLocked)
    }

    func testPasswordFallback() {
        let auth = AuthService(keychain: InMemoryKeychain())
        auth.setPassword("phrase très solide")

        XCTAssertFalse(auth.unlock(password: "autre chose"))
        XCTAssertTrue(auth.unlock(password: "phrase très solide"))
        XCTAssertFalse(auth.isLocked)
    }
}

final class PassphraseGeneratorTests: XCTestCase {
    func testFormatIsWordWordNumberWord() {
        for _ in 0..<50 {
            let passphrase = PassphraseGenerator.generate()
            let parts = passphrase.split(separator: "-").map(String.init)

            XCTAssertEqual(parts.count, 4)
            XCTAssertTrue(PassphraseGenerator.words.contains(parts[0]))
            XCTAssertTrue(PassphraseGenerator.words.contains(parts[1]))
            XCTAssertNotNil(Int(parts[2]))
            XCTAssertTrue((10...99).contains(Int(parts[2])!))
            XCTAssertTrue(PassphraseGenerator.words.contains(parts[3]))
        }
    }
}
