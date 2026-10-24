import SwiftData
import SwiftUI

@main
struct AtenaPrintApp: App {
    @State private var store = StoreService()
    @State private var layoutStore = LayoutStore()
    private let container: Result<ModelContainer, any Error>

    init() {
        container = Result { try PersistenceController.makeContainer() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(store)
                    .environment(layoutStore)
            case .failure(let error):
                DataStoreErrorView(error: error)
            }
        }
    }
}
