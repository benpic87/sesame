import SwiftData
import SwiftUI

@main
struct SesameApp: App {
    private let container: ModelContainer
    private let appStorage: UserDefaults
    @State private var auth: AuthService
    @State private var store = StoreService()
    @State private var incoming: IncomingArchive
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

        let incomingArchive = IncomingArchive()
        #if DEBUG
        if isUITesting {
            Self.deliverTestArchive(to: incomingArchive)
        }
        #endif
        _incoming = State(initialValue: incomingArchive)
        // Aucune copie de partage en clair ne doit survivre au lancement précédent.
        ShareService.purgeStaging()
    }

    private static let uiTestingDefaultsSuite = "app.sesame.ui-testing"

    #if DEBUG
    /// Tests d'interface : archive `.sesame` remise à l'app comme le fait iOS
    /// pour un fichier reçu (copie dans `Documents/Inbox`, puis ouverture).
    /// L'outil de test ne sait pas transmettre un fichier à l'app de façon
    /// fiable d'une version d'iOS à l'autre ; le contenu arrive donc par
    /// l'environnement de lancement (`SESAME_UITEST_ARCHIVE`, en base64).
    private static func deliverTestArchive(to incoming: IncomingArchive) {
        let environment = ProcessInfo.processInfo.environment
        guard let base64 = environment["SESAME_UITEST_ARCHIVE"],
              let data = Data(base64Encoded: base64) else { return }
        let name = environment["SESAME_UITEST_ARCHIVE_NAME"] ?? "Archive"

        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appendingPathComponent("\(name).sesame")
        guard (try? data.write(to: url)) != nil else { return }
        incoming.receive(url)
    }

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
                .environment(incoming)
                .defaultAppStorage(appStorage)
                .tint(Theme.accent)
                // Archive .sesame ouverte depuis AirDrop, Fichiers, Mail…
                .onOpenURL { url in incoming.receive(url) }
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
