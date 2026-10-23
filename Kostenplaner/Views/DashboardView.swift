import SwiftUI

struct DashboardView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(RouterPath.self) private var router
    @State private var selectedPeriod: BudgetPeriod = .month
    @State private var referenceDate = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PeriodPicker(selection: $selectedPeriod)
                PeriodDateNavigator(period: selectedPeriod, referenceDate: $referenceDate)
                summaryGrid
                quickActions
                recentTransactions
                debtPreview
                SyncStatusView()
            }
            .padding()
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.08))
        #endif
    }

    private var summaryGrid: some View {
        let summary = store.summary(for: selectedPeriod, referenceDate: referenceDate)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MoneyCard(title: selectedPeriod.summaryTitle, amountCents: summary.balanceCents, symbol: "chart.line.uptrend.xyaxis", accent: summary.balanceCents >= 0 ? .green : .red)
            MoneyCard(title: "Budget übrig", amountCents: summary.remainingBudgetCents, symbol: "wallet.pass.fill", accent: summary.remainingBudgetCents >= 0 ? .teal : .orange)
            MoneyCard(title: "Einnahmen", amountCents: summary.incomeCents, symbol: "arrow.down.circle.fill", accent: .blue)
            MoneyCard(title: "Ausgaben", amountCents: summary.expenseCents, symbol: "arrow.up.circle.fill", accent: .red)
            MoneyCard(title: "Offene Schulden", amountCents: summary.openDebtCents, symbol: "person.2.fill", accent: .purple)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                router.present(.transaction(.expense))
            } label: {
                Label("Ausgabe", systemImage: "minus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button {
                router.present(.transaction(.income))
            } label: {
                Label("Einnahme", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var recentTransactions: some View {
        let periodTransactions = store.transactions(for: selectedPeriod, referenceDate: referenceDate)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Letzte Buchungen")
                    .font(.headline)
                Spacer()
                Text(selectedPeriod.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if periodTransactions.isEmpty {
                EmptyStateView(title: "Noch keine Buchungen", message: "Erfasse deine erste Ausgabe oder Einnahme.", symbol: "list.bullet.rectangle")
            } else {
                ForEach(periodTransactions.prefix(4)) { transaction in
                    Button {
                        router.path.append(.transaction(transaction.id))
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var debtPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Freunde schulden dir")
                    .font(.headline)
                Spacer()
                Button {
                    router.present(.debt)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neue Schuld")
            }

            if store.openDebts.isEmpty {
                EmptyStateView(title: "Alles ausgeglichen", message: "Hier erscheinen offene Beträge von Freunden.", symbol: "checkmark.circle")
            } else {
                ForEach(store.openDebts.prefix(3)) { debt in
                    DebtRow(debt: debt)
                }
            }
        }
    }
}
