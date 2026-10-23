import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Ausgabe"
        case .income: "Einnahme"
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case allTime = "all_time"
    case month
    case week
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime: "Gesamt"
        case .month: "Monat"
        case .week: "Woche"
        case .day: "Tag"
        }
    }

    var budgetTitle: String {
        switch self {
        case .allTime: "Gesamtbudget"
        case .month: "Monatsbudget"
        case .week: "Wochenbudget"
        case .day: "Tagesbudget"
        }
    }

    var summaryTitle: String {
        switch self {
        case .allTime: "Gesamtbilanz"
        case .month: "Monatsbilanz"
        case .week: "Wochenbilanz"
        case .day: "Tagesbilanz"
        }
    }
}

struct BudgetTransaction: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID?
    var title: String
    var amountCents: Int
    var kind: TransactionKind
    var categoryID: UUID
    var date: Date
    var note: String
    var isFixed: Bool
    var repeatsMonthly: Bool
    var receiptPath: String?
    var receiptFileName: String?
    var receiptMimeType: String?
    var receiptUploadedAt: Date?

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        title: String,
        amountCents: Int,
        kind: TransactionKind,
        categoryID: UUID,
        date: Date = .now,
        note: String = "",
        isFixed: Bool = false,
        repeatsMonthly: Bool = false,
        receiptPath: String? = nil,
        receiptFileName: String? = nil,
        receiptMimeType: String? = nil,
        receiptUploadedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.title = title
        self.amountCents = amountCents
        self.kind = kind
        self.categoryID = categoryID
        self.date = date
        self.note = note
        self.isFixed = isFixed
        self.repeatsMonthly = repeatsMonthly
        self.receiptPath = receiptPath
        self.receiptFileName = receiptFileName
        self.receiptMimeType = receiptMimeType
        self.receiptUploadedAt = receiptUploadedAt
    }
}

struct ReceiptMetadata: Codable, Hashable {
    var path: String
    var fileName: String
    var mimeType: String
    var uploadedAt: Date
}

struct SpendingCategory: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID?
    var name: String
    var symbol: String
    var colorName: String

    init(id: UUID = UUID(), userID: UUID? = nil, name: String, symbol: String, colorName: String) {
        self.id = id
        self.userID = userID
        self.name = name
        self.symbol = symbol
        self.colorName = colorName
    }
}

struct Budget: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID?
    var categoryID: UUID?
    var title: String
    var limitCents: Int
    var period: BudgetPeriod
    var month: Date

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        categoryID: UUID? = nil,
        title: String,
        limitCents: Int,
        period: BudgetPeriod = .month,
        month: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.categoryID = categoryID
        self.title = title
        self.limitCents = limitCents
        self.period = period
        self.month = month
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID
        case categoryID
        case title
        case limitCents
        case period
        case month
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decodeIfPresent(UUID.self, forKey: .userID)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        title = try container.decode(String.self, forKey: .title)
        limitCents = try container.decode(Int.self, forKey: .limitCents)
        period = try container.decodeIfPresent(BudgetPeriod.self, forKey: .period) ?? .month
        month = try container.decode(Date.self, forKey: .month)
    }
}

struct Debt: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID?
    var friendName: String
    var amountCents: Int
    var note: String
    var dueDate: Date?
    var isPaid: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        friendName: String,
        amountCents: Int,
        note: String = "",
        dueDate: Date? = nil,
        isPaid: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userID = userID
        self.friendName = friendName
        self.amountCents = amountCents
        self.note = note
        self.dueDate = dueDate
        self.isPaid = isPaid
        self.createdAt = createdAt
    }
}

struct DashboardSummary {
    var incomeCents: Int
    var expenseCents: Int
    var budgetLimitCents: Int
    var openDebtCents: Int

    var balanceCents: Int { incomeCents - expenseCents }
    var remainingBudgetCents: Int { budgetLimitCents - expenseCents }
}
