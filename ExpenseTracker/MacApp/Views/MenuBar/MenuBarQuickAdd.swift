import SwiftUI
import ExpenseTracker
import SwiftData

/// Compact quick-add form shown in the menu bar popover, for jotting down a
/// single expense or income without opening the main window or importing a
/// document.
struct MenuBarQuickAdd: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var settingsResults: [AppSettings]

    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var descriptionText: String = ""
    @State private var categoryId: String = "other"
    @State private var selectedAccount: Account?
    @State private var justSaved = false

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String { settings.currency }

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
        guard let parsed = Double(amount.replacingOccurrences(of: ",", with: ".")), parsed > 0 else { return false }
        return !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)

            Picker("Type", selection: $transactionType) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: transactionType) {
                if !availableCategories.contains(where: { $0.id == categoryId }) {
                    categoryId = availableCategories.first?.id ?? "other"
                }
            }

            TextField("Amount", text: $amount)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            TextField("Description", text: $descriptionText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: descriptionText) { updateCategorySuggestion() }

            Picker("Category", selection: $categoryId) {
                ForEach(availableCategories, id: \.id) { cat in
                    Text("\(cat.icon) \(cat.name)").tag(cat.id)
                }
            }

            if !accounts.isEmpty {
                Picker("Account", selection: $selectedAccount) {
                    Text("None").tag(Account?.none)
                    ForEach(accounts) { account in
                        Text(account.displayName).tag(Account?.some(account))
                    }
                }
            }

            HStack {
                if justSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                Button("Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            if !availableCategories.contains(where: { $0.id == categoryId }) {
                categoryId = availableCategories.first?.id ?? "other"
            }
        }
    }

    // MARK: - Actions

    private func updateCategorySuggestion() {
        let text = descriptionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let detected = DefaultCategories.detectCategory(from: text, transactionType: transactionType)
        if detected.id != "other", availableCategories.contains(where: { $0.id == detected.id }) {
            categoryId = detected.id
        }
    }

    private func save() {
        guard let parsed = Double(amount.replacingOccurrences(of: ",", with: ".")), parsed > 0 else { return }

        let transaction = Transaction(
            type: transactionType,
            amount: parsed,
            currency: currency,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
            date: Date(),
            categoryId: categoryId,
            account: selectedAccount
        )
        DataService(modelContext: modelContext).addTransaction(transaction)

        // Reset for the next quick entry.
        amount = ""
        descriptionText = ""
        justSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            justSaved = false
        }
    }
}
