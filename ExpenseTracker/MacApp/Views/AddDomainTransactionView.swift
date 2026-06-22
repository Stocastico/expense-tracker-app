import SwiftUI
import SwiftData

/// A minimal add-transaction sheet that writes through `ExpenseRepository`.
/// Thin shell over `ExpenseTransactionFormModel`.
struct AddDomainTransactionView: View {
    /// An existing transaction to edit, or `nil` to add a new one.
    var editing: ExpenseDomain.Transaction? = nil
    /// Called after a successful save (so the list can reload).
    let onSaved: () -> Void

    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var model: ExpenseTransactionFormModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(editing == nil ? "New transaction" : "Edit transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model?.save() }
                        .disabled(model == nil)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 320)
        .task { ensureModel() }
    }

    @ViewBuilder
    private func form(_ model: ExpenseTransactionFormModel) -> some View {
        @Bindable var model = model
        Form {
            TextField("Amount", text: $model.amountText)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $model.type) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            TextField("Merchant", text: $model.merchant)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $model.descriptionText)
                .textFieldStyle(.roundedBorder)
            DatePicker("Date", selection: $model.date, displayedComponents: .date)

            if model.type == .expense {
                Picker("Category", selection: $model.selectedCategoryId) {
                    Text("None").tag(UUID?.none)
                    ForEach(model.categories) { category in
                        Text(category.displayName).tag(UUID?.some(category.id))
                    }
                }
                if !model.subcategories.isEmpty {
                    Picker("Subcategory", selection: $model.selectedSubcategoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(model.subcategories) { subcategory in
                            Text(subcategory.displayName).tag(UUID?.some(subcategory.id))
                        }
                    }
                }
            }

            if !model.accounts.isEmpty {
                Picker("Account", selection: $model.selectedAccountId) {
                    Text("None").tag(UUID?.none)
                    ForEach(model.accounts) { account in
                        Text(account.name).tag(UUID?.some(account.id))
                    }
                }
            }

            if !model.availableTags.isEmpty {
                Section("Tags") {
                    ForEach(model.availableTags) { tag in
                        Toggle(tag.displayName, isOn: Binding(
                            get: { model.selectedTagIds.contains(tag.id) },
                            set: { isOn in
                                if isOn { model.selectedTagIds.insert(tag.id) }
                                else { model.selectedTagIds.remove(tag.id) }
                            }
                        ))
                    }
                }
            }

            scheduleAndNoteSections(model)
        }
        .formStyle(.grouped)
    }

    /// The recurring-schedule controls and the note field. Extracted to keep the
    /// `Form` builder small enough for the compiler to infer.
    @ViewBuilder
    private func scheduleAndNoteSections(_ model: ExpenseTransactionFormModel) -> some View {
        @Bindable var model = model
        Section {
            Toggle("Recurring", isOn: $model.isRecurring)
            if model.isRecurring {
                Picker("Frequency", selection: $model.recurringFrequency) {
                    ForEach(RecurringFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                Toggle("End date", isOn: $model.hasEndDate)
                if model.hasEndDate {
                    DatePicker("End date", selection: $model.recurringEndDate, displayedComponents: .date)
                }
            }
        }

        Section("Note") {
            TextField("Note", text: $model.note)
        }
    }

    private func ensureModel() {
        guard model == nil else { return }
        let created = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: errorPresenter,
            editing: editing,
            accounts: accounts.map { .init(id: $0.id, name: $0.name) },
            onSaved: {
                dismiss()
                onSaved()
            }
        )
        created.load()
        model = created
    }
}
