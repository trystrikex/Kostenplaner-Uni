import SwiftUI

struct DebtsView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(RouterPath.self) private var router

    var body: some View {
        List {
            Section("Offen") {
                ForEach(store.debts.filter { !$0.isPaid }) { debt in
                    Button {
                        router.path.append(.debt(debt.id))
                    } label: {
                        DebtRow(debt: debt)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button {
                            store.toggleDebt(debt)
                        } label: {
                            Label("Bezahlt", systemImage: "checkmark")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            store.deleteDebt(debt)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            Section("Bezahlt") {
                ForEach(store.debts.filter { $0.isPaid }) { debt in
                    DebtRow(debt: debt)
                        .swipeActions {
                            Button {
                                store.toggleDebt(debt)
                            } label: {
                                Label("Wieder öffnen", systemImage: "arrow.uturn.backward")
                            }
                        }
                }
            }
        }
        .overlay {
            if store.debts.isEmpty {
                EmptyStateView(title: "Keine Schulden", message: "Trage ein, wenn dir jemand Geld schuldet.", symbol: "person.2")
            }
        }
        .toolbar {
            ToolbarItem(placement: .appTrailing) {
                Button {
                    router.present(.debt)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neue Schuld")
            }
        }
    }
}

struct DebtRow: View {
    let debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: debt.isPaid ? "checkmark.circle.fill" : "person.crop.circle.fill")
                .foregroundStyle(debt.isPaid ? .green : .purple)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(debt.friendName)
                    .font(.body.weight(.medium))
                if !debt.note.isEmpty {
                    Text(debt.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(MoneyFormatter.format(cents: debt.amountCents))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

struct DebtDetailView: View {
    @Environment(BudgetStore.self) private var store
    let debtID: UUID

    var body: some View {
        if let debt = store.debts.first(where: { $0.id == debtID }) {
            List {
                Section("Schuld") {
                    LabeledContent("Freund", value: debt.friendName)
                    LabeledContent("Betrag", value: MoneyFormatter.format(cents: debt.amountCents))
                    LabeledContent("Status", value: debt.isPaid ? "Bezahlt" : "Offen")
                    if let dueDate = debt.dueDate {
                        LabeledContent("Fällig", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    if !debt.note.isEmpty {
                        Text(debt.note)
                    }
                }
            }
            .navigationTitle(debt.friendName)
        } else {
            EmptyStateView(title: "Nicht gefunden", message: "Dieser Eintrag existiert nicht mehr.", symbol: "exclamationmark.triangle")
        }
    }
}
