import Foundation
import LocalAuthentication
import Observation

/// Logique d'auto-verrouillage pure, testable sans horloge réelle.
struct AutoLockPolicy {
    /// Délai d'inactivité avant verrouillage (60 s par défaut).
    var interval: TimeInterval = 60

    func shouldLock(lastActivity: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastActivity) >= interval
    }
}

enum AuthMethod: String {
    case faceID, pin, password
}

/// Verrouillage du coffre : Face ID par défaut, repli PIN (6 chiffres),
/// puis mot de passe. Auto-verrouillage après inactivité et à chaque
/// passage en arrière-plan.
@Observable
final class AuthService {
    private static let pinKey = "pin-hash.v1"
    private static let passwordKey = "password-hash.v1"
    private static let faceIDKey = "faceid-enabled"
    private static let autoLockKey = "autolock-interval"

    private let keychain: KeychainStoring
    private var timer: Timer?

    private(set) var isLocked = true
    private(set) var lastActivityAt = Date()

    /// Anti-force brute : 5 échecs PIN/mot de passe → attente de 30 s.
    private(set) var failedAttempts = 0
    private(set) var lockoutUntil: Date?

    var isThrottled: Bool {
        guard let lockoutUntil else { return false }
        return Date.now < lockoutUntil
    }

    var faceIDEnabled: Bool {
        didSet { defaults.set(faceIDEnabled, forKey: Self.faceIDKey) }
    }

    var autoLockInterval: TimeInterval {
        didSet { defaults.set(autoLockInterval, forKey: Self.autoLockKey) }
    }

    /// Préférences (Face ID, délai) ; injectables pour isoler les tests.
    private let defaults: UserDefaults

    init(keychain: KeychainStoring = KeychainStore(), defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
        faceIDEnabled = defaults.object(forKey: Self.faceIDKey) as? Bool ?? true
        autoLockInterval = defaults.object(forKey: Self.autoLockKey) as? TimeInterval ?? 60
        startAutoLockTimer()
    }

    var hasPIN: Bool { keychain.data(for: Self.pinKey) != nil }
    var hasPassword: Bool { keychain.data(for: Self.passwordKey) != nil }

    var biometricsAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: Déverrouillage

    @MainActor
    func unlockWithBiometrics() async -> Bool {
        guard faceIDEnabled, biometricsAvailable else { return false }
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Code PIN ou mot de passe")
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: String(localized: "Déverrouiller votre coffre Sésame")
            )
            if success { unlock() }
            return success
        } catch {
            return false
        }
    }

    func unlock(pin: String) -> Bool {
        guard !isThrottled, verify(pin: pin) else {
            registerFailedAttempt()
            return false
        }
        unlock()
        return true
    }

    /// Vérifie le PIN sans modifier l'état de verrouillage.
    func verify(pin: String) -> Bool {
        guard let stored = keychain.data(for: Self.pinKey) else { return false }
        return CryptoService.verifySecret(pin, against: stored)
    }

    func unlock(password: String) -> Bool {
        guard !isThrottled,
              let stored = keychain.data(for: Self.passwordKey),
              CryptoService.verifySecret(password, against: stored)
        else {
            registerFailedAttempt()
            return false
        }
        unlock()
        return true
    }

    private func unlock() {
        isLocked = false
        failedAttempts = 0
        lockoutUntil = nil
        registerActivity()
    }

    private func registerFailedAttempt() {
        guard !isThrottled else { return }
        failedAttempts += 1
        if failedAttempts >= 5 {
            lockoutUntil = .now.addingTimeInterval(30)
            failedAttempts = 0
        }
    }

    func lock() {
        isLocked = true
    }

    // MARK: Configuration des secrets

    func setPIN(_ pin: String) {
        keychain.set(CryptoService.hashSecret(pin), for: Self.pinKey)
    }

    func setPassword(_ password: String) {
        keychain.set(CryptoService.hashSecret(password), for: Self.passwordKey)
    }

    func removePassword() {
        keychain.delete(Self.passwordKey)
    }

    // MARK: Auto-verrouillage

    func registerActivity(now: Date = .now) {
        lastActivityAt = now
    }

    func lockIfInactive(now: Date = .now) {
        guard !isLocked else { return }
        let policy = AutoLockPolicy(interval: autoLockInterval)
        if policy.shouldLock(lastActivity: lastActivityAt, now: now) {
            lock()
        }
    }

    private func startAutoLockTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.lockIfInactive()
        }
    }

    deinit {
        timer?.invalidate()
    }
}
