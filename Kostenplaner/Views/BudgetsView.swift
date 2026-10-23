import SwiftUI

struct BudgetsView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(RouterPath.self) private var router
    @State private var selectedPeriod: BudgetPeriod = .month
    @State private var referenceDate = Date()

    var body: some View {
        let periodBudgets = store.budgets(for: selectedPeriod)

        List {
            Section {
                PeriodPicker(selection: $selectedPeriod)
                PeriodDateNavigator(period: selectedPeriod, referenceDate: $referenceDate)
            }

            if periodBudgets.isEmpty {
                EmptyStateView(title: "Keine Budgets", message: "Lege ein \(selectedPeriod.budgetTitle.lowercased()) oder Kategorie-Budget an.", symbol: "wallet.pass")
            } else {
                Section(selectedPeriod.budgetTitle) {
                    ForEach(periodBudgets) { budget in
                        Button {
                            router.path.append(.budget(budget.id))
                        } label: {
                            BudgetRow(budget: budget, referenceDate: referenceDate)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteBudget(budget)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .appTrailing) {
                Button {
                    router.present(.budget)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neues Budget")
            }
        }
    }
}

struct BudgetRow: View {
    @Environment(BudgetStore.self) private var store
    let budget: Budget
    let referenceDate: Date

    var body: some View {
        let spent = store.spentCents(for: budget, referenceDate: referenceDate)
        let progress = min(Double(spent) / Double(max(budget.limitCents, 1)), 1)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.title)
                        .font(.body.weight(.medium))
                    Text(budget.period.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(MoneyFormatter.format(cents: spent)) / \(MoneyFormatter.format(cents: budget.limitCents))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .tint(progress > 0.9 ? .orange : .teal)
        }
        .padding(.vertical, 4)
    }
}

struct BudgetDetailView: View {
    @Environment(BudgetStore.self) private var store
    let budgetID: UUID
    @State private var referenceDate = Date()

    var body: some View {
        if let budget = store.budgets.first(where: { $0.id == budgetID }) {
            List {
                Section {
                    PeriodDateNavigator(period: budget.period, referenceDate: $referenceDate)
                }

                Section("Budget") {
                    LabeledContent("Name", value: budget.title)
                    LabeledContent("Zeitraum", value: budget.period.title)
                    LabeledContent("Limit", value: MoneyFormatter.format(cents: budget.limitCents))
                    LabeledContent("Ausgegeben", value: MoneyFormatter.format(cents: store.spentCents(for: budget, referenceDate: referenceDate)))
                    if budget.period == .month {
                        LabeledContent("Monat", value: budget.month.monthKey)
                    }
                }
            }
            .navigationTitle(budget.title)
        } else {
            EmptyStateView(title: "Nicht gefunden", message: "Dieses Budget existiert nicht mehr.", symbol: "exclamationmark.triangle")
        }
    }
}
