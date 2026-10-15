import SwiftData
import SwiftUI

@main
struct SesameApp: App {
    private let container: ModelContainer
    private let appStorage: UserDefaults
    @State private var auth: AuthService
    @State private var store = StoreService()
    @State private var vault: VaultStore
    @Environment(\.scenePhase) private var scenePhase

    /// Lancement par les tests d'interface (argument `-ui-testing`) : état neuf
    /// et isolé (trousseau, base, coffre et préférences à part), sans toucher
    /// aux données réelles de l'appareil. Inactif en Release.
    #if DEBUG
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    #else
    static let isUITesting = false
    #endif

    init() {
        let isUITesting = Self.isUITesting
        do {
            // Base en mémoire pendant les tests : pas d'accès disque,
            // pas d'état résiduel entre deux exécutions.
            let isTesting = isUITesting
                || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isTesting)
            container = try ModelContainer(
                for: Document.self, Category.self,
                configurations: configuration
            )
        } catch {
            fatalError("Impossible d'initialiser la base locale : \(error)")
        }

        let keychain: KeychainStoring = isUITesting ? InMemoryKeychain() : KeychainStore()
        let vaultDirectoryName = isUITesting ? "Vault-UITests" : "Vault"
        if isUITesting {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.removeItem(at: support.appendingPathComponent(vaultDirectoryName))
            UserDefaults.standard.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            appStorage = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) ?? .standard
        } else {
            appStorage = .standard
        }

        _auth = State(initialValue: AuthService(keychain: keychain, defaults: appStorage))
        _vault = State(initialValue: VaultStore(
            modelContext: container.mainContext,
            crypto: CryptoService(keychain: keychain),
            directoryName: vaultDirectoryName
        ))
        // Aucune copie de partage en clair ne doit survivre au lancement précédent.
        ShareService.purgeStaging()
    }

    private static let uiTestingDefaultsSuite = "app.sesame.ui-testing"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(vault)
                .environment(store)
                .defaultAppStorage(appStorage)
                .tint(Theme.accent)
                .onChange(of: scenePhase) { _, newPhase in
                    // Verrouillage à chaque passage en arrière-plan.
                    if newPhase == .background {
                        auth.lock()
                    }
                }
        }
        .modelContainer(container)
    }
}
