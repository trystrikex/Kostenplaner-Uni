import Foundation
import Observation

@MainActor
@Observable
final class BudgetStore {
    var transactions: [BudgetTransaction]
    var categories: [SpendingCategory]
    var budgets: [Budget]
    var debts: [Debt]
    var isSyncing = false
    var syncMessage = "Bereit für deine Buchungen."

    init(
        transactions: [BudgetTransaction]? = nil,
        categories: [SpendingCategory]? = nil,
        budgets: [Budget]? = nil,
        debts: [Debt]? = nil
    ) {
        if transactions == nil,
           categories == nil,
           budgets == nil,
           debts == nil,
           let snapshot = BudgetLocalStorage.load() {
            self.transactions = snapshot.transactions
            self.categories = snapshot.categories.isEmpty ? BudgetFixtures.categories : snapshot.categories
            self.budgets = snapshot.budgets
            self.debts = snapshot.debts
            syncMessage = "Lokale Daten geladen."
        } else {
            self.transactions = transactions ?? BudgetFixtures.transactions
            self.categories = categories ?? BudgetFixtures.categories
            self.budgets = budgets ?? BudgetFixtures.budgets
            self.debts = debts ?? BudgetFixtures.debts
        }
    }

    var currentMonthTransactions: [BudgetTransaction] {
        transactions(for: .month)
    }

    var openDebts: [Debt] {
        debts.filter { !$0.isPaid }.sorted { $0.createdAt > $1.createdAt }
    }

    var summary: DashboardSummary {
        summary(for: .month)
    }

    func transactions(for period: BudgetPeriod, referenceDate: Date = .now) -> [BudgetTransaction] {
        transactions
            .filter { period.contains($0.date, referenceDate: referenceDate) }
            .sorted { $0.date > $1.date }
    }

    func budgets(for period: BudgetPeriod) -> [Budget] {
        budgets.filter { $0.period == period }
    }

    func summary(for period: BudgetPeriod, referenceDate: Date = .now) -> DashboardSummary {
        let periodTransactions = transactions(for: period, referenceDate: referenceDate)
        let income = periodTransactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amountCents }
        let expenses = periodTransactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
        let limits = budgets(for: period).reduce(0) { $0 + $1.limitCents }
        let debts = openDebts.reduce(0) { $0 + $1.amountCents }
        return DashboardSummary(incomeCents: income, expenseCents: expenses, budgetLimitCents: limits, openDebtCents: debts)
    }

    func category(for id: UUID) -> SpendingCategory {
        categories.first { $0.id == id } ?? BudgetFixtures.fallbackCategory
    }

    func spentCents(for budget: Budget, referenceDate: Date = .now) -> Int {
        transactions(for: budget.period, referenceDate: referenceDate)
            .filter { $0.kind == .expense }
            .filter { budget.categoryID == nil || $0.categoryID == budget.categoryID }
            .reduce(0) { $0 + $1.amountCents }
    }

    func addTransaction(_ transaction: BudgetTransaction) {
        transactions.insert(transaction, at: 0)
        saveLocal(message: "Buchung lokal gespeichert.")
        Task { await sync() }
    }

    func deleteTransaction(_ transaction: BudgetTransaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveLocal(message: "Buchung lokal gelöscht.")
        Task {
            if let receiptPath = transaction.receiptPath {
                try? await SupabaseGateway.shared.deleteReceipt(path: receiptPath)
            }
            await deleteFromCloud(table: "transactions", id: transaction.id)
        }
    }

    func addBudget(_ budget: Budget) {
        budgets.insert(budget, at: 0)
        saveLocal(message: "Budget lokal gespeichert.")
        Task { await sync() }
    }

    func deleteBudget(_ budget: Budget) {
        budgets.removeAll { $0.id == budget.id }
        saveLocal(message: "Budget lokal gelöscht.")
        Task { await deleteFromCloud(table: "budgets", id: budget.id) }
    }

    func addDebt(_ debt: Debt) {
        debts.insert(debt, at: 0)
        saveLocal(message: "Schuld lokal gespeichert.")
        Task { await sync() }
    }

    func toggleDebt(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].isPaid.toggle()
        saveLocal(message: "Schuld lokal aktualisiert.")
        Task { await sync() }
    }

    func deleteDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
        saveLocal(message: "Schuld lokal gelöscht.")
        Task { await deleteFromCloud(table: "debts", id: debt.id) }
    }

    func sync() async {
        guard SupabaseConfig.isConfigured else {
            syncMessage = "Lokal gespeichert. Cloud-Sync ist nicht konfiguriert."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await SupabaseGateway.shared.sync(
                transactions: transactions,
                budgets: budgets,
                debts: debts,
                categories: categories
            )
            syncMessage = "Cloud-Sync abgeschlossen."
        } catch {
            syncMessage = "Lokal gespeichert. Cloud-Sync fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func refreshFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let snapshot = try await SupabaseGateway.shared.fetchSnapshot()
            categories = snapshot.categories.isEmpty ? categories : snapshot.categories
            budgets = snapshot.budgets
            debts = snapshot.debts
            transactions = snapshot.transactions
            saveLocal(message: "Cloud-Daten lokal gespeichert.")
            syncMessage = "Cloud-Daten geladen."
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    private func saveLocal(message: String) {
        do {
            try BudgetLocalStorage.save(
                BudgetStorageSnapshot(
                    transactions: transactions,
                    categories: categories,
                    budgets: budgets,
                    debts: debts
                )
            )
            syncMessage = message
        } catch {
            syncMessage = "Lokales Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func deleteFromCloud(table: String, id: UUID) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await SupabaseGateway.shared.delete(table: table, id: id)
            syncMessage = "Cloud-Eintrag gelöscht."
        } catch {
            syncMessage = error.localizedDescription
        }
    }
}

struct BudgetStorageSnapshot: Codable {
    var transactions: [BudgetTransaction]
    var categories: [SpendingCategory]
    var budgets: [Budget]
    var debts: [Debt]
}

enum BudgetLocalStorage {
    private static let fileName = "kostenplaner-data.json"

    static func load() -> BudgetStorageSnapshot? {
        guard let fileURL else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(BudgetStorageSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: BudgetStorageSnapshot) throws {
        guard let fileURL else { return }

        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Kostenplaner", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension BudgetPeriod {
    func contains(_ date: Date, referenceDate: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .allTime:
            return true
        case .day:
            return calendar.isDate(date, inSameDayAs: referenceDate)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
                return false
            }
            return interval.contains(date)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else {
                return false
            }
            return interval.contains(date)
        }
    }
}

enum BudgetFixtures {
    static let rentID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let foodID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let leisureID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let incomeID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    static let uniID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!

    static let categories = [
        SpendingCategory(id: rentID, name: "Miete", symbol: "house.fill", colorName: "teal"),
        SpendingCategory(id: foodID, name: "Einkauf", symbol: "cart.fill", colorName: "green"),
        SpendingCategory(id: leisureID, name: "Freizeit", symbol: "sparkles", colorName: "purple"),
        SpendingCategory(id: incomeID, name: "Einkommen", symbol: "banknote.fill", colorName: "blue"),
        SpendingCategory(id: uniID, name: "Uni", symbol: "graduationcap.fill", colorName: "orange")
    ]

    static let fallbackCategory = SpendingCategory(name: "Sonstiges", symbol: "tag.fill", colorName: "gray")

    static let transactions: [BudgetTransaction] = []

    static let budgets: [Budget] = []

    static let debts: [Debt] = []
}
