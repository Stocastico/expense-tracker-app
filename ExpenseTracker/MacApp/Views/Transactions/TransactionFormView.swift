import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TransactionFormView: View {
    let transaction: Transaction?
    let currency: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var settingsResults: [AppSettings]

    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var descriptionText: String = ""
    @State private var merchant: String = ""
    @State private var date: Date = Date()
    @State private var categoryId: String = "other"
    @State private var selectedAccount: Account?
    @State private var tagsText: String = ""
    @State private var notes: String = ""
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    @State private var hasEndDate: Bool = false
    @State private var recurringEndDate: Date = Date().monthsFromNow(12)
    @State private var receiptData: Data?
    @State private var suggestedCategoryId: String?
    @State private var showDeleteConfirmation = false
    @State private var isProcessingOCR = false

    private var isEditing: Bool { transaction != nil }

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var availableCategories: [Category] {
        let all = settings.allCategories
        switch transactionType {
        case .expense:
            return all.filter { $0.type == .expense || $0.type == .both }
        case .income:
            return all.filter { $0.type == .income || $0.type == .both }
        }
    }

    private var isValid: Bool {
        guard let parsedAmount = Double(amount), parsedAmount > 0 else { return false }
        return !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Transaction" : "New Transaction")
                    .font(.headline)
                Spacer()
                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type toggle
                    Picker("Type", selection: $transactionType) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: transactionType) {
                        // Reset category if not compatible with new type
                        if !availableCategories.contains(where: { $0.id == categoryId }) {
                            categoryId = availableCategories.first?.id ?? "other"
                        }
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .textFieldStyle(.plain)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What was this for?", text: $descriptionText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: descriptionText) {
                                updateCategorySuggestion()
                            }
                    }

                    // Merchant
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merchant (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Store or payee", text: $merchant)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: merchant) {
                                updateCategorySuggestion()
                            }
                    }

                    // Smart category suggestion
                    if let suggestedId = suggestedCategoryId, suggestedId != categoryId {
                        let cat = DefaultCategories.category(withId: suggestedId)
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Suggested: \(cat.icon) \(cat.name)")
                                .font(.caption)
                            Button("Apply") {
                                categoryId = suggestedId
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }

                    // Date
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        categoryGrid
                    }

                    // Account picker
                    Picker("Account", selection: $selectedAccount) {
                        Text("None").tag(Account?.none)
                        ForEach(accounts) { account in
                            Text(account.displayName).tag(Account?.some(account))
                        }
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("tag1, tag2, tag3", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 60, maxHeight: 100)
                            .border(Color.secondary.opacity(0.2))
                    }

                    // Recurring
                    Toggle("Recurring", isOn: $isRecurring)

                    if isRecurring {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Frequency", selection: $recurringFrequency) {
                                ForEach(RecurringFrequency.allCases) { freq in
                                    Text(freq.displayName).tag(freq)
                                }
                            }

                            Toggle("End Date", isOn: $hasEndDate)
                            if hasEndDate {
                                DatePicker("End Date", selection: $recurringEndDate, displayedComponents: .date)
                            }
                        }
                        .padding(.leading, 20)
                    }

                    // Receipt scan
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Receipt")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                openReceiptFilePicker()
                            } label: {
                                Label(
                                    receiptData != nil ? "Replace Receipt" : "Scan Receipt",
                                    systemImage: "doc.viewfinder"
                                )
                            }

                            if isProcessingOCR {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Processing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if receiptData != nil {
                                Button(role: .destructive) {
                                    receiptData = nil
                                } label: {
                                    Label("Remove", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                        }

                        if let data = receiptData, let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save Changes" : "Add Transaction") {
                    saveTransaction()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .onAppear {
            populateFromTransaction()
        }
        .confirmationDialog(
            "Delete Transaction",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                if let transaction {
                    let dataService = DataService(modelContext: modelContext)
                    dataService.deleteTransaction(transaction)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this transaction?")
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(availableCategories, id: \.id) { cat in
                Button {
                    categoryId = cat.id
                } label: {
                    VStack(spacing: 2) {
                        Text(cat.icon)
                            .font(.title2)
                        Text(cat.name)
                            .font(.system(size: 8))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryId == cat.id
                                ? Color(hex: cat.color).opacity(0.25)
                                : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(categoryId == cat.id
                                ? Color(hex: cat.color)
                                : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func populateFromTransaction() {
        guard let t = transaction else {
            // Default to first account or default account
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            return
        }
        transactionType = t.type
        amount = String(format: "%.2f", t.storedAmount)
        descriptionText = t.descriptionText
        merchant = t.merchant ?? ""
        date = t.date
        categoryId = t.categoryId
        selectedAccount = t.account
        tagsText = t.tags.joined(separator: ", ")
        notes = t.notes ?? ""
        isRecurring = t.isRecurring
        if let freq = t.recurringFrequency {
            recurringFrequency = freq
        }
        if let endDate = t.recurringEndDate {
            hasEndDate = true
            recurringEndDate = endDate
        }
        receiptData = t.receiptData
    }

    private func updateCategorySuggestion() {
        let text = [descriptionText, merchant].compactMap { $0 }.joined(separator: " ")
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestedCategoryId = nil
            return
        }
        let detected = DefaultCategories.detectCategory(from: text, transactionType: transactionType)
        if detected.id != "other" {
            suggestedCategoryId = detected.id
        } else {
            suggestedCategoryId = nil
        }
    }

    private func saveTransaction() {
        guard let parsedAmount = Double(amount), parsedAmount > 0 else { return }

        let dataService = DataService(modelContext: modelContext)
        let tags = tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing = transaction {
            existing.type = transactionType
            existing.storedAmount = parsedAmount
            existing.currency = currency
            existing.descriptionText = descriptionText.trimmingCharacters(in: .whitespaces)
            existing.merchant = merchant.isEmpty ? nil : merchant
            existing.date = date
            existing.categoryId = categoryId
            existing.account = selectedAccount
            existing.tags = tags
            existing.notes = notes.isEmpty ? nil : notes
            existing.isRecurring = isRecurring
            existing.recurringFrequency = isRecurring ? recurringFrequency : nil
            existing.recurringEndDate = isRecurring && hasEndDate ? recurringEndDate : nil
            existing.receiptData = receiptData
            dataService.updateTransaction(existing)
        } else {
            let newTransaction = Transaction(
                type: transactionType,
                amount: parsedAmount,
                currency: currency,
                descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
                merchant: merchant.isEmpty ? nil : merchant,
                date: date,
                categoryId: categoryId,
                account: selectedAccount,
                tags: tags,
                notes: notes.isEmpty ? nil : notes,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil,
                recurringEndDate: isRecurring && hasEndDate ? recurringEndDate : nil,
                receiptData: receiptData
            )

            dataService.addTransaction(newTransaction)

            // Generate recurring instances if applicable
            if isRecurring {
                let endDate = hasEndDate ? recurringEndDate : Date().monthsFromNow(12)
                let instances = generateRecurringInstances(from: newTransaction, until: endDate)
                for instance in instances {
                    dataService.addTransaction(instance)
                }
            }
        }

        dismiss()
    }

    private func generateRecurringInstances(from parent: Transaction, until endDate: Date) -> [Transaction] {
        guard let frequency = parent.recurringFrequency else { return [] }
        var instances: [Transaction] = []
        var nextDate = frequency.nextDate(from: parent.date)

        while nextDate <= endDate {
            let instance = Transaction(
                type: parent.type,
                amount: parent.storedAmount,
                currency: parent.currency,
                descriptionText: parent.descriptionText,
                merchant: parent.merchant,
                date: nextDate,
                categoryId: parent.categoryId,
                account: parent.account,
                tags: parent.tags,
                notes: parent.notes,
                isRecurring: true,
                recurringFrequency: parent.recurringFrequency,
                recurringEndDate: parent.recurringEndDate,
                recurringParentId: parent.id
            )
            instances.append(instance)
            nextDate = frequency.nextDate(from: nextDate)
        }

        return instances
    }

    private func openReceiptFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a receipt image to scan"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        receiptData = data
        isProcessingOCR = true

        Task {
            do {
                let text = try await OCRService.recognizeText(from: data)
                if let result = OCRService.extractExpenseFromText(text) {
                    await MainActor.run {
                        if let ocrAmount = result.amount {
                            amount = String(format: "%.2f", ocrAmount)
                        }
                        if let ocrMerchant = result.merchant {
                            merchant = ocrMerchant
                            updateCategorySuggestion()
                        }
                        if let ocrDate = result.date {
                            date = ocrDate
                        }
                        transactionType = .expense
                        isProcessingOCR = false
                    }
                } else {
                    await MainActor.run {
                        isProcessingOCR = false
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingOCR = false
                }
            }
        }
    }
}
