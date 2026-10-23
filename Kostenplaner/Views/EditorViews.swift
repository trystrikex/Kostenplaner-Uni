import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
#endif

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetStore.self) private var store

    let kind: TransactionKind
    @State private var title = ""
    @State private var amount = ""
    @State private var categoryID = BudgetFixtures.foodID
    @State private var date = Date()
    @State private var note = ""
    @State private var isFixed = false
    @State private var repeatsMonthly = false
    @State private var isSaving = false

    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var receiptDraft: ReceiptImageDraft?
    @State private var isCameraPresented = false
    @State private var isScanningReceipt = false
    @State private var receiptMessage = "Wähle ein Foto oder einen Screenshot aus."
    #endif

    var body: some View {
        Form {
            Section(kind.title) {
                TextField("Titel", text: $title)
                AmountField(text: $amount)
                Picker("Kategorie", selection: $categoryID) {
                    ForEach(availableCategories) { category in
                        Label(category.name, systemImage: category.symbol)
                            .tag(category.id)
                    }
                }
                DatePicker("Datum", selection: $date, displayedComponents: .date)
            }

            if kind == .expense {
                receiptSection
            }

            Section("Planung") {
                Toggle("Fixkosten", isOn: $isFixed)
                Toggle("Monatlich wiederholen", isOn: $repeatsMonthly)
                TextField("Notiz", text: $note, axis: .vertical)
            }
        }
        .navigationTitle("Neue \(kind.title)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Speichern..." : "Speichern") {
                    Task { await save() }
                }
                .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyFormatter.parseToCents(amount) <= 0)
            }
        }
        .onAppear {
            ensureValidCategorySelection()
        }
        #if os(iOS)
        .sheet(isPresented: $isCameraPresented) {
            ReceiptCameraPicker { image in
                Task { await handleReceiptImage(image, fileName: "beleg-kamera.jpg") }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await loadPhotoItem(item) }
        }
        #endif
    }

    private var availableCategories: [SpendingCategory] {
        let filtered = store.categories.filter { category in
            switch kind {
            case .income:
                category.id == BudgetFixtures.incomeID
            case .expense:
                category.id != BudgetFixtures.incomeID
            }
        }
        return filtered.isEmpty ? store.categories : filtered
    }

    private func ensureValidCategorySelection() {
        if !availableCategories.contains(where: { $0.id == categoryID }),
           let firstCategory = availableCategories.first {
            categoryID = firstCategory.id
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        #if os(iOS)
        Section("Beleg") {
            if let receiptDraft {
                ReceiptPreview(
                    draft: receiptDraft,
                    message: receiptMessage,
                    isScanning: isScanningReceipt
                ) {
                    self.receiptDraft = nil
                    receiptMessage = "Beleg entfernt."
                }
            } else {
                Text(receiptMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Galerie", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    isCameraPresented = true
                } label: {
                    Label("Kamera", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
        }
        #else
        Section("Beleg") {
            Text("Beleg-Upload ist auf iOS verfügbar.")
                .foregroundStyle(.secondary)
        }
        #endif
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let transactionID = UUID()
        var receiptMetadata: ReceiptMetadata?

        #if os(iOS)
        if let receiptDraft {
            do {
                receiptMetadata = try await ReceiptStorageService.uploadReceipt(receiptDraft, transactionID: transactionID)
            } catch {
                store.syncMessage = "Buchung ohne Beleg gespeichert: \(error.localizedDescription)"
            }
        }
        #endif

        let transaction = BudgetTransaction(
            id: transactionID,
            title: title,
            amountCents: MoneyFormatter.parseToCents(amount),
            kind: kind,
            categoryID: categoryID,
            date: date,
            note: note,
            isFixed: isFixed,
            repeatsMonthly: repeatsMonthly,
            receiptPath: receiptMetadata?.path,
            receiptFileName: receiptMetadata?.fileName,
            receiptMimeType: receiptMetadata?.mimeType,
            receiptUploadedAt: receiptMetadata?.uploadedAt
        )
        store.addTransaction(transaction)
        dismiss()
    }

    #if os(iOS)
    private func loadPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                receiptMessage = "Das Bild konnte nicht geladen werden."
                return
            }
            await handleReceiptImage(image, fileName: "beleg-galerie.jpg")
        } catch {
            receiptMessage = error.localizedDescription
        }
    }

    private func handleReceiptImage(_ image: UIImage, fileName: String) async {
        receiptDraft = ReceiptImageDraft(image: image, fileName: fileName)
        isScanningReceipt = true
        receiptMessage = "Betrag wird erkannt..."
        defer { isScanningReceipt = false }

        if let recognizedCents = await ReceiptOCRService.recognizedAmountCents(from: image) {
            amount = MoneyFormatter.format(cents: recognizedCents)
                .replacingOccurrences(of: "€", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            receiptMessage = "Erkannter Betrag: \(MoneyFormatter.format(cents: recognizedCents)). Du kannst ihn ändern."
        } else {
            receiptMessage = "Kein Betrag erkannt. Du kannst den Betrag manuell eintragen."
        }
    }
    #endif
}

struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetStore.self) private var store

    @State private var title = ""
    @State private var amount = ""
    @State private var useCategory = false
    @State private var categoryID = BudgetFixtures.foodID
    @State private var period: BudgetPeriod = .month

    var body: some View {
        Form {
            Section("Budget") {
                TextField("Name", text: $title)
                AmountField(text: $amount)
                Picker("Zeitraum", selection: $period) {
                    ForEach(BudgetPeriod.allCases) { period in
                        Text(period.budgetTitle).tag(period)
                    }
                }
                Toggle("Für Kategorie", isOn: $useCategory)

                if useCategory {
                    Picker("Kategorie", selection: $categoryID) {
                        ForEach(store.categories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(category.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Neues Budget")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    let budget = Budget(
                        categoryID: useCategory ? categoryID : nil,
                        title: title,
                        limitCents: MoneyFormatter.parseToCents(amount),
                        period: period
                    )
                    store.addBudget(budget)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyFormatter.parseToCents(amount) <= 0)
            }
        }
    }
}

struct DebtEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetStore.self) private var store

    @State private var friendName = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        Form {
            Section("Freund") {
                TextField("Name", text: $friendName)
                AmountField(text: $amount)
                TextField("Notiz", text: $note, axis: .vertical)
            }

            Section("Optional") {
                Toggle("Fälligkeitsdatum", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Fällig", selection: $dueDate, displayedComponents: .date)
                }
            }
        }
        .navigationTitle("Neue Schuld")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    let debt = Debt(
                        friendName: friendName,
                        amountCents: MoneyFormatter.parseToCents(amount),
                        note: note,
                        dueDate: hasDueDate ? dueDate : nil
                    )
                    store.addDebt(debt)
                    dismiss()
                }
                .disabled(friendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyFormatter.parseToCents(amount) <= 0)
            }
        }
    }
}
