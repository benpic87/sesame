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
        let vaultDirectoryName = isUITesting ? "Vault-UITests" : "Vault"
        if isUITesting {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.removeItem(at: support.appendingPathComponent(vaultDirectoryName))
        }

        do {
            // Base en mémoire pendant les tests : pas d'accès disque,
            // pas d'état résiduel entre deux exécutions. Sinon, dans le
            // dossier du coffre, exclu des sauvegardes.
            let isTesting = isUITesting
                || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let configuration = isTesting
                ? ModelConfiguration(isStoredInMemoryOnly: true)
                : ModelConfiguration(url: VaultStore.metadataStoreURL(
                    in: VaultStore.preparedDirectory(named: vaultDirectoryName)
                ))
            container = try ModelContainer(
                for: Document.self, Category.self,
                configurations: configuration
            )
        } catch {
            fatalError("Impossible d'initialiser la base locale : \(error)")
        }

        let keychain: KeychainStoring = isUITesting ? InMemoryKeychain() : KeychainStore()
        if isUITesting {
            UserDefaults.standard.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            appStorage = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) ?? .standard
        } else {
            appStorage = .standard
        }

        _auth = State(initialValue: AuthService(keychain: keychain, defaults: appStorage))
        let vaultStore = VaultStore(
            modelContext: container.mainContext,
            crypto: CryptoService(keychain: keychain),
            directoryName: vaultDirectoryName
        )
        #if DEBUG
        if isUITesting, ProcessInfo.processInfo.arguments.contains("-seed-portrait-document") {
            Self.seedPortraitDocument(in: vaultStore)
        }
        #endif
        _vault = State(initialValue: vaultStore)
        // Aucune copie de partage en clair ne doit survivre au lancement précédent.
        ShareService.purgeStaging()
    }

    private static let uiTestingDefaultsSuite = "app.sesame.ui-testing"

    #if DEBUG
    /// Tests d'interface : une photo très haute, dont la vignette (scaledToFill)
    /// déborde de sa carte — cas qui recouvrait les catégories.
    private static func seedPortraitDocument(in vault: VaultStore) {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 1200)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 1200))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        _ = try? vault.importDocument(data: data, name: "Photo portrait", type: .image, fileExtension: "jpg")
    }
    #endif

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
