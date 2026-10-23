import Foundation

#if canImport(Supabase)
import Supabase
#endif

enum SupabaseGatewayError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase ist noch nicht konfiguriert. Trage Project URL und publishable key in SupabaseConfig.swift ein."
        }
    }
}

actor SupabaseGateway {
    static let shared = SupabaseGateway()

    #if canImport(Supabase)
    private let client = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.publishableKey
    )
    #endif

    func sendLoginCode(email: String) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }
        #if canImport(Supabase)
        try await client.auth.signInWithOTP(email: email, redirectTo: SupabaseConfig.loginRedirectURL)
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func handleLoginCallback(url: URL) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }
        #if canImport(Supabase)
        try await client.auth.session(from: url)
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func signOut() async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }
        #if canImport(Supabase)
        try await client.auth.signOut()
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func sync(
        transactions: [BudgetTransaction],
        budgets: [Budget],
        debts: [Debt],
        categories: [SpendingCategory]
    ) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        try await client.from("categories").upsert(categories.map(SupabaseCategoryRow.init)).execute()
        try await client.from("budgets").upsert(budgets.map(SupabaseBudgetRow.init)).execute()
        try await client.from("debts").upsert(debts.map(SupabaseDebtRow.init)).execute()
        try await client.from("transactions").upsert(transactions.map(SupabaseTransactionRow.init)).execute()
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func fetchSnapshot() async throws -> SupabaseSnapshot {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        async let categoryRows: [SupabaseCategoryRow] = client
            .from("categories")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
        async let budgetRows: [SupabaseBudgetRow] = client
            .from("budgets")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        async let debtRows: [SupabaseDebtRow] = client
            .from("debts")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        async let transactionRows: [SupabaseTransactionRow] = client
            .from("transactions")
            .select()
            .order("date", ascending: false)
            .execute()
            .value

        return try await SupabaseSnapshot(
            categories: categoryRows.map(\.model),
            budgets: budgetRows.map(\.model),
            debts: debtRows.map(\.model),
            transactions: transactionRows.map(\.model)
        )
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func delete(table: String, id: UUID) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        try await client.from(table).delete().eq("id", value: id.uuidString).execute()
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func deleteReceipt(path: String) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        try await client.storage.from("receipts").remove(paths: [path])
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func uploadReceipt(data: Data, transactionID: UUID, fileName: String, mimeType: String) async throws -> ReceiptMetadata {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        let user = try await client.auth.user()
        let sanitizedName = fileName.replacingOccurrences(of: "/", with: "-")
        let path = "\(user.id.uuidString)/\(transactionID.uuidString)/\(sanitizedName)"

        try await client.storage
            .from("receipts")
            .upload(
                path: path,
                file: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: mimeType,
                    upsert: true
                )
            )

        return ReceiptMetadata(path: path, fileName: sanitizedName, mimeType: mimeType, uploadedAt: .now)
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }

    func signedReceiptURL(path: String, expiresIn seconds: Int = 600) async throws -> URL {
        guard SupabaseConfig.isConfigured else { throw SupabaseGatewayError.notConfigured }

        #if canImport(Supabase)
        return try await client.storage
            .from("receipts")
            .createSignedURL(path: path, expiresIn: seconds)
        #else
        throw SupabaseGatewayError.notConfigured
        #endif
    }
}

struct SupabaseSnapshot {
    var categories: [SpendingCategory]
    var budgets: [Budget]
    var debts: [Debt]
    var transactions: [BudgetTransaction]
}

private struct SupabaseCategoryRow: Codable {
    var id: UUID
    var name: String
    var symbol: String
    var colorName: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case colorName = "color_name"
    }

    init(_ category: SpendingCategory) {
        id = category.id
        name = category.name
        symbol = category.symbol
        colorName = category.colorName
    }

    var model: SpendingCategory {
        SpendingCategory(id: id, name: name, symbol: symbol, colorName: colorName)
    }
}

private struct SupabaseTransactionRow: Codable {
    var id: UUID
    var title: String
    var amountCents: Int
    var kind: TransactionKind
    var categoryID: UUID
    var date: String
    var note: String
    var isFixed: Bool
    var repeatsMonthly: Bool
    var receiptPath: String?
    var receiptFileName: String?
    var receiptMimeType: String?
    var receiptUploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amountCents = "amount_cents"
        case kind
        case categoryID = "category_id"
        case date
        case note
        case isFixed = "is_fixed"
        case repeatsMonthly = "repeats_monthly"
        case receiptPath = "receipt_path"
        case receiptFileName = "receipt_file_name"
        case receiptMimeType = "receipt_mime_type"
        case receiptUploadedAt = "receipt_uploaded_at"
    }

    init(_ transaction: BudgetTransaction) {
        id = transaction.id
        title = transaction.title
        amountCents = transaction.amountCents
        kind = transaction.kind
        categoryID = transaction.categoryID
        date = transaction.date.isoDate
        note = transaction.note
        isFixed = transaction.isFixed
        repeatsMonthly = transaction.repeatsMonthly
        receiptPath = transaction.receiptPath
        receiptFileName = transaction.receiptFileName
        receiptMimeType = transaction.receiptMimeType
        receiptUploadedAt = transaction.receiptUploadedAt?.isoDate
    }

    var model: BudgetTransaction {
        BudgetTransaction(
            id: id,
            title: title,
            amountCents: amountCents,
            kind: kind,
            categoryID: categoryID,
            date: Date.isoDateFormatter.date(from: date) ?? .now,
            note: note,
            isFixed: isFixed,
            repeatsMonthly: repeatsMonthly,
            receiptPath: receiptPath,
            receiptFileName: receiptFileName,
            receiptMimeType: receiptMimeType,
            receiptUploadedAt: receiptUploadedAt.flatMap { Date.isoDateFormatter.date(from: $0) }
        )
    }
}

private struct SupabaseBudgetRow: Codable {
    var id: UUID
    var categoryID: UUID?
    var title: String
    var limitCents: Int
    var period: BudgetPeriod
    var month: String

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case title
        case limitCents = "limit_cents"
        case period
        case month
    }

    init(_ budget: Budget) {
        id = budget.id
        categoryID = budget.categoryID
        title = budget.title
        limitCents = budget.limitCents
        period = budget.period
        month = budget.month.isoDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        title = try container.decode(String.self, forKey: .title)
        limitCents = try container.decode(Int.self, forKey: .limitCents)
        period = try container.decodeIfPresent(BudgetPeriod.self, forKey: .period) ?? .month
        month = try container.decode(String.self, forKey: .month)
    }

    var model: Budget {
        Budget(
            id: id,
            categoryID: categoryID,
            title: title,
            limitCents: limitCents,
            period: period,
            month: Date.isoDateFormatter.date(from: month) ?? .now
        )
    }
}

private struct SupabaseDebtRow: Codable {
    var id: UUID
    var friendName: String
    var amountCents: Int
    var note: String
    var dueDate: String?
    var isPaid: Bool
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case friendName = "friend_name"
        case amountCents = "amount_cents"
        case note
        case dueDate = "due_date"
        case isPaid = "is_paid"
        case createdAt = "created_at"
    }

    init(_ debt: Debt) {
        id = debt.id
        friendName = debt.friendName
        amountCents = debt.amountCents
        note = debt.note
        dueDate = debt.dueDate?.isoDate
        isPaid = debt.isPaid
        createdAt = debt.createdAt.isoDate
    }

    var model: Debt {
        Debt(
            id: id,
            friendName: friendName,
            amountCents: amountCents,
            note: note,
            dueDate: dueDate.flatMap { Date.isoDateFormatter.date(from: $0) },
            isPaid: isPaid,
            createdAt: Date.isoDateFormatter.date(from: createdAt) ?? .now
        )
    }
}

private extension Date {
    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var isoDate: String {
        Self.isoDateFormatter.string(from: self)
    }
}
