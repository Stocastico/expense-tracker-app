import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    // MARK: - Form State

    @State private var amountText: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var descriptionText: String = ""
    @State private var selectedCategoryId: String = ""
    @State private var selectedAccountId: UUID?
    @State private var date: Date = Date()
    @State private var merchant: String = ""
    @State private var notes: String = ""
    @State private var showMerchantField: Bool = false
    @State private var showNotesField: Bool = false
    @State private var showSuccessFeedback: Bool = false

    // MARK: - Computed Properties

    private var filteredCategories: [Category] {
        switch transactionType {
        case .expense:
            return DefaultCategories.expenseCategories
        case .income:
            return DefaultCategories.incomeCategories
        }
    }

    private var currencySymbol: String {
        let settings = fetchSettings()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = settings.currency
        return formatter.currencySymbol ?? settings.currency
    }

    private var selectedAccount: Account? {
        if let id = selectedAccountId {
            return accounts.first { $0.id == id }
        }
        return accounts.first { $0.isDefault } ?? accounts.first
    }

    private var isFormValid: Bool {
        guard let amount = Double(amountText), amount > 0 else { return false }
        guard !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !selectedCategoryId.isEmpty else { return false }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountSection
                    typePickerSection
                    descriptionSection
                    categoryGridSection
                    accountPickerSection
                    datePickerSection
                    optionalFieldsSection
                    saveButton
                }
                .padding()
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if showSuccessFeedback {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                initializeDefaults()
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $amountText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Type Picker

    private var typePickerSection: some View {
        Picker("Type", selection: $transactionType) {
            ForEach(TransactionType.allCases) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: transactionType) { _, _ in
            // Reset category when switching types if current is invalid
            if !filteredCategories.contains(where: { $0.id == selectedCategoryId }) {
                selectedCategoryId = filteredCategories.first?.id ?? ""
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("What was this for?", text: $descriptionText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: descriptionText) { _, newValue in
                    autoSuggestCategory(from: newValue)
                }
        }
    }

    // MARK: - Category Grid

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredCategories) { category in
                    categoryButton(for: category)
                }
            }
        }
    }

    private func categoryButton(for category: Category) -> some View {
        Button {
            selectedCategoryId = category.id
        } label: {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title2)
                Text(category.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedCategoryId == category.id
                          ? Color.accentColor.opacity(0.15)
                          : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedCategoryId == category.id
                            ? Color.accentColor
                            : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account Picker

    private var accountPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(accounts) { account in
                        accountChip(for: account)
                    }
                }
            }
        }
    }

    private func accountChip(for account: Account) -> some View {
        let isSelected = (selectedAccountId ?? accounts.first(where: { $0.isDefault })?.id ?? accounts.first?.id) == account.id

        return Button {
            selectedAccountId = account.id
        } label: {
            HStack(spacing: 4) {
                Text(account.icon)
                Text(account.name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.15)
                          : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Picker

    private var datePickerSection: some View {
        DatePicker("Date", selection: $date, displayedComponents: [.date])
            .datePickerStyle(.compact)
    }

    // MARK: - Optional Fields

    private var optionalFieldsSection: some View {
        VStack(spacing: 12) {
            if showMerchantField {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Merchant")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Merchant name", text: $merchant)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: merchant) { _, newValue in
                            autoSuggestCategory(from: descriptionText, merchant: newValue)
                        }
                }
            } else {
                Button {
                    withAnimation { showMerchantField = true }
                } label: {
                    Label("Add merchant", systemImage: "storefront")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if showNotesField {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            } else {
                Button {
                    withAnimation { showNotesField = true }
                } label: {
                    Label("Add notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            Text(transactionType == .expense ? "Save Expense" : "Save Income")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isFormValid ? Color.accentColor : Color.gray)
                )
        }
        .disabled(!isFormValid)
        .padding(.top, 8)
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Transaction saved!")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func initializeDefaults() {
        if selectedCategoryId.isEmpty {
            selectedCategoryId = filteredCategories.first?.id ?? ""
        }
        if selectedAccountId == nil {
            selectedAccountId = accounts.first(where: { $0.isDefault })?.id ?? accounts.first?.id
        }
    }

    private func autoSuggestCategory(from description: String, merchant: String? = nil) {
        let merchantValue = merchant ?? (showMerchantField ? self.merchant : nil)
        if let suggestedId = SmartCategoryService.suggestCategory(
            for: description,
            merchant: merchantValue
        ) {
            // Only auto-suggest if the suggested category is valid for current type
            if filteredCategories.contains(where: { $0.id == suggestedId }) {
                selectedCategoryId = suggestedId
            }
        }
    }

    private func saveTransaction() {
        guard let amount = Double(amountText), amount > 0 else { return }

        let transaction = Transaction(
            type: transactionType,
            amount: amount,
            currency: fetchSettings().currency,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
            merchant: showMerchantField && !merchant.trimmingCharacters(in: .whitespaces).isEmpty
                ? merchant.trimmingCharacters(in: .whitespaces)
                : nil,
            date: date,
            categoryId: selectedCategoryId,
            account: selectedAccount,
            notes: showNotesField && !notes.trimmingCharacters(in: .whitespaces).isEmpty
                ? notes.trimmingCharacters(in: .whitespaces)
                : nil
        )

        modelContext.insert(transaction)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save transaction: \(error.localizedDescription)")
            return
        }

        // Show success feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccessFeedback = true
        }

        // Reset form
        resetForm()

        // Hide feedback after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccessFeedback = false
            }
        }
    }

    private func resetForm() {
        amountText = ""
        descriptionText = ""
        selectedCategoryId = filteredCategories.first?.id ?? ""
        date = Date()
        merchant = ""
        notes = ""
        showMerchantField = false
        showNotesField = false
    }

    private func fetchSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            return settings
        }
        return AppSettings()
    }
}
