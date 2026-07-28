import SwiftData
import SwiftUI

@main
struct SesameApp: App {
    private let container: ModelContainer
    @State private var auth = AuthService()
    @State private var store = StoreService()
    @State private var vault: VaultStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            container = try ModelContainer(for: Document.self, Category.self)
        } catch {
            fatalError("Impossible d'initialiser la base locale : \(error)")
        }
        _vault = State(initialValue: VaultStore(modelContext: container.mainContext))
        // Aucune copie de partage en clair ne doit survivre au lancement précédent.
        ShareService.purgeStaging()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(vault)
                .environment(store)
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
