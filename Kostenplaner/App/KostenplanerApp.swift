import SwiftUI

@main
struct KostenplanerApp: App {
    @State private var store = BudgetStore()
    @State private var auth = AuthState()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(store)
                .environment(auth)
                .onOpenURL { url in
                    Task {
                        await auth.handleLoginCallback(url: url)
                        if auth.isAuthenticated {
                            await store.sync()
                        }
                    }
                }
        }
    }
}
