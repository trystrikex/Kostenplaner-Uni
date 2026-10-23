import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case budgets
    case debts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Übersicht"
        case .transactions: "Buchungen"
        case .budgets: "Budgets"
        case .debts: "Schulden"
        case .settings: "Einstellungen"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .transactions: "list.bullet.rectangle"
        case .budgets: "wallet.pass.fill"
        case .debts: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@MainActor
@Observable
final class RouterPath {
    var path: [Route] = []
    var presentedSheet: SheetDestination?

    func present(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }
}

enum Route: Hashable {
    case transaction(UUID)
    case budget(UUID)
    case debt(UUID)
}

enum SheetDestination: Identifiable, Hashable {
    case transaction(TransactionKind)
    case budget
    case debt

    var id: String {
        switch self {
        case .transaction(let kind): "transaction-\(kind.rawValue)"
        case .budget: "budget"
        case .debt: "debt"
        }
    }
}

struct AppShellView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var dashboardRouter = RouterPath()
    @State private var transactionsRouter = RouterPath()
    @State private var budgetsRouter = RouterPath()
    @State private var debtsRouter = RouterPath()
    @State private var settingsRouter = RouterPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            tab(.dashboard, router: dashboardRouter) {
                DashboardView()
            }
            tab(.transactions, router: transactionsRouter) {
                TransactionsView()
            }
            tab(.budgets, router: budgetsRouter) {
                BudgetsView()
            }
            tab(.debts, router: debtsRouter) {
                DebtsView()
            }
            tab(.settings, router: settingsRouter) {
                SettingsView()
            }
        }
        .tint(.teal)
    }

    private func router(for tab: AppTab) -> RouterPath {
        switch tab {
        case .dashboard: dashboardRouter
        case .transactions: transactionsRouter
        case .budgets: budgetsRouter
        case .debts: debtsRouter
        case .settings: settingsRouter
        }
    }

    private func tab<Content: View>(
        _ tab: AppTab,
        router: RouterPath,
        @ViewBuilder content: () -> Content
    ) -> some View {
        @Bindable var router = router

        return NavigationStack(path: $router.path) {
            content()
                .navigationTitle(tab.title)
                .withRouteDestinations()
        }
        .sheet(item: $router.presentedSheet) { destination in
            NavigationStack {
                SheetContentView(destination: destination)
            }
        }
        .environment(router)
        .tabItem {
            Label(tab.title, systemImage: tab.icon)
        }
        .tag(tab)
    }
}

private struct SheetContentView: View {
    let destination: SheetDestination

    var body: some View {
        switch destination {
        case .transaction(let kind):
            TransactionEditorView(kind: kind)
        case .budget:
            BudgetEditorView()
        case .debt:
            DebtEditorView()
        }
    }
}

extension View {
    func withRouteDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .transaction(let id):
                TransactionDetailView(transactionID: id)
            case .budget(let id):
                BudgetDetailView(budgetID: id)
            case .debt(let id):
                DebtDetailView(debtID: id)
            }
        }
    }
}
