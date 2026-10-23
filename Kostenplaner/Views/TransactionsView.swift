import SwiftUI

struct TransactionsView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(RouterPath.self) private var router
    @State private var selectedPeriod: BudgetPeriod = .month
    @State private var referenceDate = Date()

    var body: some View {
        let periodTransactions = store.transactions(for: selectedPeriod, referenceDate: referenceDate)

        List {
            Section {
                PeriodPicker(selection: $selectedPeriod)
                PeriodDateNavigator(period: selectedPeriod, referenceDate: $referenceDate)
            }

            if periodTransactions.isEmpty {
                EmptyStateView(title: "Keine Buchungen", message: "Tippe auf +, um Einnahmen oder Ausgaben zu erfassen.", symbol: "tray")
            } else {
                Section(selectedPeriod.title) {
                    ForEach(periodTransactions) { transaction in
                        Button {
                            router.path.append(.transaction(transaction.id))
                        } label: {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteTransaction(transaction)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .appTrailing) {
                Button {
                    router.present(.transaction(.income))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Neue Einnahme")

                Button {
                    router.present(.transaction(.expense))
                } label: {
                    Image(systemName: "minus.circle")
                }
                .accessibilityLabel("Neue Ausgabe")
            }
        }
    }
}

struct TransactionRow: View {
    @Environment(BudgetStore.self) private var store
    let transaction: BudgetTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.category(for: transaction.categoryID).symbol)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(transaction.title)
                        .font(.body.weight(.medium))
                    if transaction.isFixed {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(store.category(for: transaction.categoryID).name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(MoneyFormatter.format(cents: transaction.kind == .expense ? -transaction.amountCents : transaction.amountCents))
                .font(.body.weight(.semibold))
                .foregroundStyle(transaction.kind == .expense ? .red : .green)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

struct TransactionDetailView: View {
    @Environment(BudgetStore.self) private var store
    let transactionID: UUID
    @State private var receiptURL: URL?
    @State private var receiptMessage = ""

    var body: some View {
        if let transaction = store.transactions.first(where: { $0.id == transactionID }) {
            List {
                Section("Buchung") {
                    LabeledContent("Titel", value: transaction.title)
                    LabeledContent("Typ", value: transaction.kind.title)
                    LabeledContent("Kategorie", value: store.category(for: transaction.categoryID).name)
                    LabeledContent("Betrag", value: MoneyFormatter.format(cents: transaction.amountCents))
                    LabeledContent("Datum", value: transaction.date.formatted(date: .abbreviated, time: .omitted))
                }

                Section("Details") {
                    LabeledContent("Fixkosten", value: transaction.isFixed ? "Ja" : "Nein")
                    LabeledContent("Monatlich", value: transaction.repeatsMonthly ? "Ja" : "Nein")
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                    }
                }

                if transaction.receiptPath != nil {
                    receiptSection(for: transaction)
                }
            }
            .navigationTitle(transaction.title)
            .task(id: transaction.receiptPath) {
                await loadReceiptURL(for: transaction)
            }
        } else {
            EmptyStateView(title: "Nicht gefunden", message: "Diese Buchung existiert nicht mehr.", symbol: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func receiptSection(for transaction: BudgetTransaction) -> some View {
        Section("Beleg") {
            if let receiptURL {
                AsyncImage(url: receiptURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Text("Beleg konnte nicht geladen werden.")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 320)

                Link("Beleg öffnen", destination: receiptURL)
            } else if receiptMessage.isEmpty {
                ProgressView("Beleg wird geladen...")
            } else {
                Text(receiptMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let fileName = transaction.receiptFileName {
                LabeledContent("Datei", value: fileName)
            }
        }
    }

    private func loadReceiptURL(for transaction: BudgetTransaction) async {
        guard let path = transaction.receiptPath else { return }
        do {
            receiptURL = try await SupabaseGateway.shared.signedReceiptURL(path: path)
            receiptMessage = ""
        } catch {
            receiptURL = nil
            receiptMessage = error.localizedDescription
        }
    }
}
