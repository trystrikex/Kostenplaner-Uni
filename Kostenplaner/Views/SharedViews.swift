import SwiftUI

extension ToolbarItemPlacement {
    static var appTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

struct MoneyCard: View {
    let title: String
    let amountCents: Int
    let symbol: String
    var accent: Color = .teal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoneyFormatter.format(cents: amountCents))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PeriodPicker: View {
    @Binding var selection: BudgetPeriod

    var body: some View {
        Picker("Zeitraum", selection: $selection) {
            ForEach(BudgetPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Zeitraum")
    }
}

struct CurrentDateBadge: View {
    private let currentDate = Date()

    var body: some View {
        Label {
            Text(currentDate.formatted(date: .complete, time: .omitted))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: "calendar")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Aktuelles Datum")
    }
}

struct PeriodDateNavigator: View {
    let period: BudgetPeriod
    @Binding var referenceDate: Date

    var body: some View {
        if period == .allTime {
            Label("Alle gespeicherten Buchungen", systemImage: "calendar.badge.clock")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        shiftReferenceDate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Vorheriger Zeitraum")

                    DatePicker(period.title, selection: $referenceDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        shiftReferenceDate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Nächster Zeitraum")
                }

                HStack {
                    Label(periodLabel, systemImage: "calendar")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button("Heute") {
                        referenceDate = .now
                    }
                    .font(.footnote.weight(.medium))
                    .disabled(Calendar.current.isDate(referenceDate, inSameDayAs: .now))
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var periodLabel: String {
        switch period {
        case .allTime:
            return "Gesamt"
        case .day:
            return referenceDate.formatted(date: .complete, time: .omitted)
        case .week:
            guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: referenceDate),
                  let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) else {
                return referenceDate.formatted(date: .abbreviated, time: .omitted)
            }
            return "\(interval.start.formatted(date: .abbreviated, time: .omitted)) - \(lastDay.formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return referenceDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private func shiftReferenceDate(by value: Int) {
        let component: Calendar.Component = switch period {
        case .allTime: .day
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        referenceDate = Calendar.current.date(byAdding: component, value: value, to: referenceDate) ?? referenceDate
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

struct AmountField: View {
    @Binding var text: String

    var body: some View {
        #if os(iOS)
        TextField("0,00", text: $text)
            .keyboardType(.decimalPad)
            .monospacedDigit()
        #else
        TextField("0,00", text: $text)
            .monospacedDigit()
        #endif
    }
}

struct CategoryLabel: View {
    let category: SpendingCategory

    var body: some View {
        Label(category.name, systemImage: category.symbol)
            .labelStyle(.titleAndIcon)
    }
}

struct SyncStatusView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            if store.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: SupabaseConfig.isConfigured ? "icloud.fill" : "icloud.slash")
                    .foregroundStyle(SupabaseConfig.isConfigured ? .teal : .secondary)
            }
            Text(store.syncMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
